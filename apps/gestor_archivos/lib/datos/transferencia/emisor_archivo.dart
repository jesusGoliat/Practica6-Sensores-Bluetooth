import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:enlace_ble/enlace_ble.dart';

import '../../dominio/transferencia/estado_transferencia.dart';
import '../../dominio/transferencia/metadatos_archivo.dart';
import '../../dominio/transferencia/registro_transferencia.dart';
import '../../dominio/transferencia/validador_transferencia.dart';

/// Lado emisor: OFERTA, espera aceptación, BLOQUE/BLOQUE_ACK, FIN_ARCHIVO.
///
/// Sin reanudación: si se pierde la conexión el registro queda `fallido` y
/// hay que reenviar desde el bloque 0.
class EmisorArchivo {
  EmisorArchivo({
    required this.enlace,
    this.nombreLocal = 'Archivos IPN',
    this.alterarBloque = false,
    this.alterarNombre = false,
    this.tiempoRespuesta = const Duration(seconds: 90),
    this.tiempoBloque = const Duration(seconds: 15),
    this.alCambiar,
  });

  final Enlace enlace;
  final String nombreLocal;

  /// Diagnóstico: corrompe un byte del bloque 1 (o del 0 si solo hay uno).
  final bool alterarBloque;

  /// Diagnóstico: anuncia un nombre inválido (`../x.txt`) para probar al receptor.
  final bool alterarNombre;
  final Duration tiempoRespuesta;
  final Duration tiempoBloque;
  final void Function(RegistroTransferencia)? alCambiar;

  bool _cancelarLocal = false;
  String? _cancelRemoto;
  String? _rechazo;
  bool _aceptada = false;
  int _ackHasta = -1;
  bool? _resultadoOk;
  String? _resultadoMotivo;
  bool _desconectado = false;
  Completer<void> _despierta = Completer<void>();

  RegistroTransferencia? _registro;
  RegistroTransferencia? get registro => _registro;

  void cancelar() {
    _cancelarLocal = true;
    _despertar();
  }

  void _despertar() {
    if (!_despierta.isCompleted) _despierta.complete();
  }

  void _emitir(RegistroTransferencia r) {
    _registro = r;
    alCambiar?.call(r);
  }

  /// Espera a que [cond] sea verdadera, se cancele, se pierda el enlace o venza [limite].
  Future<bool> _hasta(bool Function() cond, Duration limite) async {
    final fin = DateTime.now().add(limite);
    while (!cond()) {
      if (_cancelarLocal || _cancelRemoto != null || _desconectado) return false;
      final resto = fin.difference(DateTime.now());
      if (resto <= Duration.zero) return false;
      _despierta = Completer<void>();
      await _despierta.future.timeout(resto, onTimeout: () {});
    }
    return true;
  }

  /// Envía [bytes] bajo el nombre lógico [nombre]. Siempre devuelve el
  /// registro final (nunca lanza).
  Future<RegistroTransferencia> enviar({
    required String id,
    required String nombre,
    required Future<Uint8List> Function() leer,
    String? dispositivo,
  }) async {
    final tipo = ValidadorTransferencia.tipoDeNombre(nombre) ?? '';
    var reg = RegistroTransferencia.nuevo(
      id: id,
      direccion: DireccionTransferencia.enviado,
      nombre: nombre,
      tipo: tipo,
      longitud: 0,
      dispositivo: dispositivo,
    );
    _emitir(reg);
    _desconectado = enlace.estadoActual != EstadoConexion.conectado;
    final subEstado = enlace.estado.listen((e) {
      if (e == EstadoConexion.desconectado) {
        _desconectado = true;
        _despertar();
      }
    });
    final sub = enlace.mensajes.listen((s) {
      if (s.canal != Canales.archivos || s.sesion != id) return;
      final d = s.datos;
      switch (s.tipo) {
        case TiposMensaje.ofertaAcepta:
          _aceptada = true;
        case TiposMensaje.ofertaRechaza:
          _rechazo = (d['motivo'] as String?) ?? 'sin motivo';
        case TiposMensaje.bloqueAck:
          final n = d['n'];
          if (n is int && n > _ackHasta) _ackHasta = n;
        case TiposMensaje.cancela:
          _cancelRemoto = (d['motivo'] as String?) ?? 'sin motivo';
        case TiposMensaje.resultado:
          _resultadoOk = d['ok'] == true;
          _resultadoMotivo = d['motivo'] as String?;
      }
      _despertar();
    });

    Future<RegistroTransferencia> terminar(EstadoTransferencia e, String motivo,
        {bool verificado = false}) async {
      reg = reg.conEstado(e, motivo: motivo.isEmpty ? null : motivo, verificado: verificado);
      _emitir(reg);
      return reg;
    }

    Future<RegistroTransferencia> abortarYCancelar(String motivoLocal) async {
      try {
        await enlace.enviar(Canales.archivos, id, TiposMensaje.cancela,
            {'id': id, 'motivo': 'usuario'});
      } catch (_) {}
      return await terminar(EstadoTransferencia.cancelado, motivoLocal);
    }

    try {
      final Uint8List bytes;
      try {
        bytes = await leer();
      } catch (e) {
        reg = reg.conEstado(EstadoTransferencia.fallido, motivo: 'no se pudo leer el archivo: $e');
        _emitir(reg);
        return reg;
      }
      final hash = sha256.convert(bytes).toString();
      final nombreOferta = alterarNombre ? '../x.txt' : nombre;
      final meta = MetadatosArchivo(
          id: id, nombre: nombreOferta, tipo: tipo, longitud: bytes.length, sha256: hash);
      reg = reg.conDatos(longitud: bytes.length, sha256: hash);
      _emitir(reg);
      if (!alterarNombre) {
        final error = ValidadorTransferencia.validarOferta(meta);
        if (error != null) return await terminar(EstadoTransferencia.fallido, error.mensaje);
      }
      if (_cancelarLocal) return await terminar(EstadoTransferencia.cancelado, 'cancelado por el usuario');

      try {
        await enlace.enviar(Canales.archivos, id, TiposMensaje.oferta,
            {...meta.toJson(), 'emisor': nombreLocal});
      } catch (_) {
        return await terminar(EstadoTransferencia.fallido, 'conexión perdida');
      }
      final respondio = await _hasta(() => _aceptada || _rechazo != null, tiempoRespuesta);
      if (_cancelarLocal) return await abortarYCancelar('cancelado por el usuario');
      if (_cancelRemoto != null) {
        return await terminar(EstadoTransferencia.cancelado, 'cancelado por el receptor');
      }
      if (_rechazo != null) {
        return await terminar(EstadoTransferencia.cancelado, _textoRechazo(_rechazo!));
      }
      if (!respondio) {
        return await terminar(EstadoTransferencia.fallido,
            _desconectado ? 'conexión perdida' : 'el receptor no respondió a la oferta');
      }
      reg = reg.conEstado(EstadoTransferencia.enCurso);
      _emitir(reg);

      final total = meta.totalBloques;
      for (var n = 0; n < total; n++) {
        if (_cancelarLocal) return await abortarYCancelar('cancelado por el usuario');
        if (_cancelRemoto != null) {
          return await terminar(EstadoTransferencia.cancelado, 'cancelado por el receptor');
        }
        final ini = n * meta.bloque;
        final fin = ini + meta.bloque > bytes.length ? bytes.length : ini + meta.bloque;
        final trozo = Uint8List.fromList(bytes.sublist(ini, fin));
        if (alterarBloque && n == (total > 1 ? 1 : 0)) trozo[0] ^= 0xFF;
        try {
          await enlace.enviar(
              Canales.archivos, id, TiposMensaje.bloque, {'id': id, 'n': n, 'b64': base64Encode(trozo)});
        } catch (_) {
          if (_cancelRemoto != null) {
            return await terminar(EstadoTransferencia.cancelado, 'cancelado por el receptor');
          }
          return await terminar(EstadoTransferencia.fallido, 'conexión perdida');
        }
        final ok = await _hasta(() => _ackHasta >= n, tiempoBloque);
        if (_cancelarLocal) return await abortarYCancelar('cancelado por el usuario');
        if (_cancelRemoto != null) {
          return await terminar(EstadoTransferencia.cancelado, 'cancelado por el receptor');
        }
        if (!ok) {
          return await terminar(EstadoTransferencia.fallido,
              _desconectado ? 'conexión perdida' : 'sin confirmación del bloque $n');
        }
        reg = reg.conDatos(progreso: fin / bytes.length);
        _emitir(reg);
      }
      if (_cancelarLocal) return await abortarYCancelar('cancelado por el usuario');
      try {
        await enlace.enviar(Canales.archivos, id, TiposMensaje.finArchivo, {'id': id});
      } catch (_) {
        return await terminar(EstadoTransferencia.fallido, 'conexión perdida');
      }
      await _hasta(() => _resultadoOk != null, tiempoBloque);
      if (_cancelRemoto != null && _resultadoOk == null) {
        return await terminar(EstadoTransferencia.cancelado, 'cancelado por el receptor');
      }
      if (_resultadoOk == true) {
        return await terminar(EstadoTransferencia.completado, '', verificado: true);
      }
      if (_resultadoOk == false) {
        return await terminar(EstadoTransferencia.fallido, _textoResultado(_resultadoMotivo));
      }
      return await terminar(EstadoTransferencia.fallido,
          _desconectado ? 'conexión perdida' : 'el receptor no confirmó el resultado');
    } finally {
      await sub.cancel();
      await subEstado.cancel();
    }
  }

  static String _textoRechazo(String m) => switch (m) {
        'usuario' => 'rechazada por el receptor',
        'ocupado' => 'el receptor está ocupado con otra transferencia',
        'nombre' => 'rechazada: nombre no válido',
        'tipo' => 'rechazada: tipo no permitido',
        'tamano' => 'rechazada: excede el tamaño permitido',
        _ => 'rechazada por el receptor ($m)',
      };

  static String _textoResultado(String? m) => switch (m) {
        'sha256' => 'integridad fallida: el SHA-256 no coincide',
        'longitud' => 'integridad fallida: la longitud no coincide',
        _ => 'el receptor reportó un error (${m ?? 'sin motivo'})',
      };
}
