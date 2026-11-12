/// Fragmentación y reensamblado (capa 1).
library;

import 'dart:typed_data';

import 'errores.dart';

/// Bytes de cabecera: `[flags:1][msgId:2 BE][indice:2 BE]`.
const int bytesCabecera = 5;

/// Tamaño máximo de un mensaje completo (64 KiB).
const int maxMensaje = 64 * 1024;

/// Bit 0 de `flags`: último fragmento.
const int banderaUltimo = 0x01;

/// Parte un mensaje en fragmentos de a lo más [maxFragmento] bytes.
class Fragmentador {
  /// Crea un fragmentador. Lanza [ArgumentError] si [maxFragmento] ≤ 5.
  Fragmentador(this.maxFragmento, {int idInicial = 0}) : _siguienteId = idInicial & 0xFFFF {
    if (maxFragmento <= bytesCabecera) {
      throw ArgumentError.value(maxFragmento, 'maxFragmento',
          'Debe ser mayor que $bytesCabecera (tamaño de la cabecera).');
    }
  }

  /// Tamaño máximo de cada fragmento, cabecera incluida.
  final int maxFragmento;

  int _siguienteId;

  /// Identificador que usará el siguiente mensaje.
  int get siguienteId => _siguienteId;

  /// Fragmenta [mensaje]. Lanza [ErrorProtocolo] (`fragmento`) si excede 64 KiB
  /// o necesitaría más de 65 536 fragmentos.
  List<Uint8List> fragmentar(Uint8List mensaje) {
    if (mensaje.length > maxMensaje) {
      throw ErrorProtocolo('fragmento',
          'El mensaje (${mensaje.length} B) excede el límite de $maxMensaje B.');
    }
    final util = maxFragmento - bytesCabecera;
    final total = mensaje.isEmpty ? 1 : (mensaje.length + util - 1) ~/ util;
    if (total > 0x10000) {
      throw ErrorProtocolo('fragmento', 'Demasiados fragmentos ($total).');
    }
    final id = _siguienteId;
    _siguienteId = (_siguienteId + 1) & 0xFFFF;
    final salida = <Uint8List>[];
    for (var i = 0; i < total; i++) {
      final ini = i * util;
      final fin = ini + util > mensaje.length ? mensaje.length : ini + util;
      final f = Uint8List(bytesCabecera + (fin - ini));
      f[0] = i == total - 1 ? banderaUltimo : 0;
      f[1] = id >> 8;
      f[2] = id & 0xFF;
      f[3] = i >> 8;
      f[4] = i & 0xFF;
      f.setRange(bytesCabecera, f.length, mensaje, ini);
      salida.add(f);
    }
    return salida;
  }
}

class _Parcial {
  _Parcial(this.inicio);
  final DateTime inicio;
  final BytesBuilder datos = BytesBuilder(copy: false);
  int siguiente = 0;
}

/// Junta fragmentos de varios mensajes (agrupados por `msgId`).
class Reensamblador {
  /// Crea un reensamblador. [reloj] es inyectable para pruebas.
  Reensamblador({
    this.tiempoLimite = const Duration(seconds: 10),
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  /// Tiempo tras el cual un mensaje incompleto se descarta.
  final Duration tiempoLimite;

  final DateTime Function() _reloj;
  final Map<int, _Parcial> _parciales = {};

  /// Mensajes incompletos en curso.
  int get pendientes => _parciales.length;

  /// Agrega un fragmento. Devuelve el mensaje completo al recibir el último,
  /// o `null` si falta más (o si el fragmento era un duplicado ignorado).
  /// Lanza [ErrorProtocolo] (`fragmento`) si es inválido, llega fuera de orden
  /// o el mensaje excede 64 KiB; en esos casos el mensaje parcial se descarta.
  Uint8List? agregar(Uint8List fragmento) {
    limpiarVencidos();
    if (fragmento.length < bytesCabecera) {
      throw const ErrorProtocolo('fragmento', 'Fragmento más corto que la cabecera.');
    }
    final ultimo = (fragmento[0] & banderaUltimo) != 0;
    final id = (fragmento[1] << 8) | fragmento[2];
    final indice = (fragmento[3] << 8) | fragmento[4];
    var p = _parciales[id];
    if (p == null) {
      if (indice != 0) {
        throw ErrorProtocolo('fragmento',
            'Fragmento $indice del mensaje $id sin haber recibido el inicio.');
      }
      p = _Parcial(_reloj());
      _parciales[id] = p;
    } else if (indice < p.siguiente) {
      return null; // duplicado
    } else if (indice > p.siguiente) {
      _parciales.remove(id);
      throw ErrorProtocolo('fragmento',
          'Fragmento fuera de orden en el mensaje $id (llegó $indice, se esperaba ${p.siguiente}).');
    }
    if (p.datos.length + fragmento.length - bytesCabecera > maxMensaje) {
      _parciales.remove(id);
      throw const ErrorProtocolo('fragmento', 'El mensaje excede el límite de 64 KiB.');
    }
    p.datos.add(Uint8List.sublistView(fragmento, bytesCabecera));
    p.siguiente++;
    if (ultimo) {
      _parciales.remove(id);
      return p.datos.takeBytes();
    }
    return null;
  }

  /// Descarta los mensajes incompletos más antiguos que [tiempoLimite].
  void limpiarVencidos() {
    final ahora = _reloj();
    _parciales.removeWhere((_, p) => ahora.difference(p.inicio) >= tiempoLimite);
  }

  /// Descarta todo lo pendiente (p. ej. al desconectar).
  void reiniciar() => _parciales.clear();
}
