import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:enlace_ble/enlace_ble.dart';
import 'package:path/path.dart' as p;

import '../../dominio/transferencia/estado_transferencia.dart';
import '../../dominio/transferencia/metadatos_archivo.dart';
import '../../dominio/transferencia/registro_transferencia.dart';
import '../../dominio/transferencia/validador_transferencia.dart';

/// Lado receptor de una transferencia (canal `archivos`).
///
/// Escribe en `tmp/<id>.part`, verifica longitud y SHA-256 y solo entonces
/// renombra a `recibidos/`. Cualquier fallo borra el temporal.
class ReceptorArchivo {
  ReceptorArchivo({
    required this.enlace,
    required this.directorioRecibidos,
    required this.directorioTmp,
    required this.decidir,
    this.alCambiar,
  }) {
    _sub = enlace.mensajes.listen(_encolar);
    _subEstado = enlace.estado.listen((e) {
      if (e == EstadoConexion.desconectado) {
        _cola = _cola.then((_) => _fallar('conexión perdida', avisar: false));
      }
    });
  }

  final Enlace enlace;
  final Directory directorioRecibidos;
  final Directory directorioTmp;

  /// Pregunta al usuario si acepta la oferta. [emisor] es el nombre declarado.
  final Future<bool> Function(MetadatosArchivo meta, String emisor) decidir;
  final void Function(RegistroTransferencia)? alCambiar;

  late final StreamSubscription<Sobre> _sub;
  late final StreamSubscription<EstadoConexion> _subEstado;
  Future<void> _cola = Future.value();

  RegistroTransferencia? _registro;
  MetadatosArchivo? _meta;
  String? _sesion;
  File? _parte;
  IOSink? _salida;
  int _siguiente = 0;
  int _escritos = 0;
  bool _decidiendo = false;

  bool get ocupado => _meta != null;
  RegistroTransferencia? get registro => _registro;

  void _encolar(Sobre s) {
    if (s.canal != Canales.archivos) return;
    _cola = _cola.then((_) => _manejar(s)).catchError((Object e) {
      return _fallar('error interno: $e');
    });
  }

  Future<void> _enviar(String tipo, Map<String, dynamic> datos, {String? sesion}) async {
    try {
      await enlace.enviar(Canales.archivos, sesion ?? _sesion!, tipo, datos);
    } catch (_) {
      // Sin enlace: la desconexión ya se trata aparte.
    }
  }

  void _emitir(RegistroTransferencia r) {
    _registro = r;
    alCambiar?.call(r);
  }

  Future<void> _manejar(Sobre s) async {
    final d = s.datos;
    if (s.tipo == TiposMensaje.oferta) return _alOferta(s);
    if (_meta == null || d['id'] != _meta!.id || s.sesion != _sesion) return;
    switch (s.tipo) {
      case TiposMensaje.bloque:
        return _alBloque(d);
      case TiposMensaje.finArchivo:
        return _alFin();
      case TiposMensaje.cancela:
        await _terminar(EstadoTransferencia.cancelado, 'cancelado por el emisor');
    }
  }

  Future<void> _alOferta(Sobre s) async {
    final meta = MetadatosArchivo.desdeJson(s.datos);
    if (meta == null) {
      await _enviar(TiposMensaje.ofertaRechaza, {'id': s.datos['id'] ?? '', 'motivo': 'formato'},
          sesion: s.sesion);
      return;
    }
    if (_meta != null || _decidiendo) {
      await _enviar(TiposMensaje.ofertaRechaza, {'id': meta.id, 'motivo': 'ocupado'},
          sesion: s.sesion);
      return;
    }
    final emisor = (s.datos['emisor'] as String?) ?? 'Dispositivo desconocido';
    final base = RegistroTransferencia.nuevo(
      id: meta.id,
      direccion: DireccionTransferencia.recibido,
      nombre: meta.nombre,
      tipo: meta.tipo,
      longitud: meta.longitud,
      sha256: meta.sha256,
      dispositivo: emisor,
    );
    final error = ValidadorTransferencia.validarOferta(meta);
    if (error != null) {
      _emitir(base.conEstado(EstadoTransferencia.fallido,
          motivo: 'oferta rechazada: ${error.mensaje}'));
      await _enviar(TiposMensaje.ofertaRechaza, {'id': meta.id, 'motivo': error.codigo},
          sesion: s.sesion);
      _registro = null;
      return;
    }
    _emitir(base);
    _decidiendo = true;
    bool acepta;
    try {
      acepta = await decidir(meta, emisor);
    } catch (_) {
      acepta = false;
    }
    _decidiendo = false;
    if (!acepta) {
      _emitir(base.conEstado(EstadoTransferencia.cancelado, motivo: 'rechazada por el usuario'));
      await _enviar(TiposMensaje.ofertaRechaza, {'id': meta.id, 'motivo': 'usuario'},
          sesion: s.sesion);
      _registro = null;
      return;
    }
    if (enlace.estadoActual != EstadoConexion.conectado) {
      _emitir(base.conEstado(EstadoTransferencia.fallido, motivo: 'conexión perdida'));
      _registro = null;
      return;
    }
    try {
      await directorioTmp.create(recursive: true);
      await directorioRecibidos.create(recursive: true);
      _parte = File(p.join(directorioTmp.path, '${meta.id}.part'));
      _salida = _parte!.openWrite();
    } catch (e) {
      _emitir(base.conEstado(EstadoTransferencia.fallido, motivo: 'no se pudo escribir: $e'));
      await _enviar(TiposMensaje.ofertaRechaza, {'id': meta.id, 'motivo': 'almacenamiento'},
          sesion: s.sesion);
      _registro = null;
      return;
    }
    _meta = meta;
    _sesion = s.sesion;
    _siguiente = 0;
    _escritos = 0;
    _emitir(base.conEstado(EstadoTransferencia.enCurso));
    await _enviar(TiposMensaje.ofertaAcepta, {'id': meta.id});
  }

  Future<void> _alBloque(Map<String, dynamic> d) async {
    final n = d['n'];
    final b64 = d['b64'];
    if (n is! int || b64 is! String) return _fallar('bloque mal formado', cancelar: true);
    if (n < _siguiente) {
      // Duplicado: se confirma sin reescribir.
      await _enviar(TiposMensaje.bloqueAck, {'id': _meta!.id, 'n': n});
      return;
    }
    if (n > _siguiente) return _fallar('bloque fuera de secuencia', cancelar: true);
    final List<int> datos;
    try {
      datos = base64Decode(b64);
    } catch (_) {
      return _fallar('bloque con base64 inválido', cancelar: true);
    }
    if (_escritos + datos.length > _meta!.longitud || datos.length > _meta!.bloque) {
      return _fallar('datos exceden la longitud anunciada', cancelar: true);
    }
    try {
      _salida!.add(datos);
      await _salida!.flush();
    } catch (e) {
      return _fallar('error de escritura: $e', cancelar: true);
    }
    _escritos += datos.length;
    _siguiente++;
    _emitir(_registro!.conDatos(progreso: _escritos / _meta!.longitud));
    await _enviar(TiposMensaje.bloqueAck, {'id': _meta!.id, 'n': n});
  }

  Future<void> _alFin() async {
    final meta = _meta!;
    final parte = _parte!;
    try {
      await _salida!.close();
      _salida = null;
      final longitud = await parte.length();
      if (longitud != meta.longitud) {
        return await _verificacionFallida('longitud', 'longitud distinta de la anunciada');
      }
      final hash = (await sha256.bind(parte.openRead()).first).toString();
      if (hash != meta.sha256.toLowerCase()) {
        return await _verificacionFallida('sha256', 'integridad fallida: SHA-256 distinto');
      }
      final nombre = ValidadorTransferencia.nombreUnico(meta.nombre,
          (n) => File(p.join(directorioRecibidos.path, n)).existsSync());
      final destino = p.join(directorioRecibidos.path, nombre);
      try {
        await parte.rename(destino);
      } on FileSystemException {
        await parte.copy(destino);
        await parte.delete();
      }
      final listo = _registro!
          .conDatos(nombre: nombre, progreso: 1)
          .conEstado(EstadoTransferencia.completado, verificado: true);
      _limpiarEstado();
      _emitir(listo);
      await _enviar(TiposMensaje.resultado, {'id': meta.id, 'ok': true}, sesion: _ultimaSesion);
    } catch (e) {
      await _verificacionFallida('almacenamiento', 'error al guardar: $e');
    }
  }

  String? _ultimaSesion;

  Future<void> _verificacionFallida(String codigo, String motivo) async {
    final id = _meta!.id;
    final sesion = _sesion!;
    await _terminar(EstadoTransferencia.fallido, motivo, notificar: false);
    await _enviar(TiposMensaje.resultado, {'id': id, 'ok': false, 'motivo': codigo},
        sesion: sesion);
  }

  Future<void> _fallar(String motivo, {bool cancelar = false, bool avisar = true}) async {
    if (_meta == null) return;
    final id = _meta!.id, sesion = _sesion!;
    await _terminar(EstadoTransferencia.fallido, motivo, notificar: false);
    if (cancelar && avisar) {
      await _enviar(TiposMensaje.cancela, {'id': id, 'motivo': motivo}, sesion: sesion);
    }
  }

  /// Cancelación por el usuario local.
  Future<void> cancelar() async {
    if (_meta == null) return;
    final id = _meta!.id, sesion = _sesion!;
    await _terminar(EstadoTransferencia.cancelado, 'cancelado por el usuario', notificar: false);
    await _enviar(TiposMensaje.cancela, {'id': id, 'motivo': 'usuario'}, sesion: sesion);
  }

  Future<void> _terminar(EstadoTransferencia estado, String motivo, {bool notificar = true}) async {
    if (_meta == null) return;
    final r = _registro!;
    final parte = _parte, salida = _salida;
    // Se libera el estado antes de cualquier espera para que un bloque en
    // vuelo ya no encuentre una transferencia activa.
    _limpiarEstado();
    await _borrar(parte, salida);
    _emitir(r.conEstado(estado, motivo: motivo));
  }

  void _limpiarEstado() {
    _ultimaSesion = _sesion;
    _meta = null;
    _sesion = null;
    _parte = null;
    _salida = null;
  }

  Future<void> _borrar(File? parte, IOSink? salida) async {
    try {
      await salida?.close();
    } catch (_) {}
    try {
      if (parte != null && parte.existsSync()) await parte.delete();
    } catch (_) {}
  }

  Future<void> cerrar() async {
    await _sub.cancel();
    await _subEstado.cancel();
    await _cola;
    if (_meta != null) {
      await _terminar(EstadoTransferencia.fallido, 'conexión perdida');
    }
  }
}
