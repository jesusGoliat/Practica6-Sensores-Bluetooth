/// Sobre JSON del protocolo (capa 2).
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'errores.dart';
import 'tipos.dart';

final RegExp _reSesion = RegExp(r'^[0-9a-f]{8}$');
final RegExp _reTipo = RegExp(r'^[A-Z][A-Z0-9_]{0,31}$');

/// Mensaje de la capa 2: `{v, canal, sesion, seq, tipo, ack, datos}`.
class Sobre {
  /// Versión actual del protocolo.
  static const int versionActual = 1;

  /// Crea un sobre. La validación estricta se hace en [Sobre.fromBytes];
  /// el constructor solo comprueba invariantes al construir en depuración.
  Sobre({
    this.v = versionActual,
    required this.canal,
    required this.sesion,
    required this.seq,
    required this.tipo,
    this.ack,
    Map<String, dynamic>? datos,
  }) : datos = datos ?? const <String, dynamic>{};

  /// Versión del protocolo.
  final int v;

  /// Canal lógico (ver [Canales]).
  final String canal;

  /// Identificador de partida/transferencia/sesión web (8 hexadecimales).
  final String sesion;

  /// Número de secuencia del emisor dentro de la sesión.
  final int seq;

  /// Tipo de mensaje (ver [TiposMensaje]).
  final String tipo;

  /// En mensajes `ACK`, el `seq` confirmado; en los demás, `null`.
  final int? ack;

  /// Carga útil JSON.
  final Map<String, dynamic> datos;

  /// Genera un identificador de sesión de 8 hexadecimales.
  static String nuevaSesion([Random? azar]) {
    final r = azar ?? Random.secure();
    return List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  /// Mapa JSON del sobre.
  Map<String, dynamic> toJson() => {
    'v': v,
    'canal': canal,
    'sesion': sesion,
    'seq': seq,
    'tipo': tipo,
    'ack': ack,
    'datos': datos,
  };

  /// Serializa a JSON UTF-8.
  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  /// Decodifica y valida estrictamente. Lanza [ErrorProtocolo] con código
  /// `formato` (no es JSON/objeto), `version` (v distinta de 1) o `campo`
  /// (campo ausente, de tipo o valor inválido).
  factory Sobre.fromBytes(Uint8List bytes) {
    final Object? crudo;
    try {
      crudo = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw ErrorProtocolo(
        'formato',
        'El mensaje no es JSON UTF-8 válido: ${e.message}',
      );
    }
    if (crudo is! Map<String, dynamic>) {
      throw const ErrorProtocolo('formato', 'El mensaje no es un objeto JSON.');
    }
    final v = crudo['v'];
    if (v is! int) {
      throw const ErrorProtocolo('campo', 'Falta el campo "v" o no es entero.');
    }
    if (v != versionActual) {
      throw ErrorProtocolo(
        'version',
        'Versión de protocolo $v no soportada (se espera $versionActual).',
      );
    }
    final canal = crudo['canal'];
    if (canal is! String || !Canales.todos.contains(canal)) {
      throw ErrorProtocolo('campo', 'Canal inválido: $canal.');
    }
    final sesion = crudo['sesion'];
    if (sesion is! String || !_reSesion.hasMatch(sesion)) {
      throw ErrorProtocolo(
        'campo',
        'Sesión inválida (se esperan 8 hexadecimales): $sesion.',
      );
    }
    final seq = crudo['seq'];
    if (seq is! int || seq < 0) {
      throw ErrorProtocolo('campo', 'seq inválido: $seq.');
    }
    final tipo = crudo['tipo'];
    if (tipo is! String || !_reTipo.hasMatch(tipo)) {
      throw ErrorProtocolo('campo', 'Tipo inválido: $tipo.');
    }
    final ack = crudo['ack'];
    if (ack != null && (ack is! int || ack < 0)) {
      throw ErrorProtocolo('campo', 'ack inválido: $ack.');
    }
    if (tipo == TiposMensaje.ack && ack == null) {
      throw const ErrorProtocolo(
        'campo',
        'Un ACK debe indicar el seq confirmado.',
      );
    }
    final datos = crudo['datos'];
    if (datos != null && datos is! Map<String, dynamic>) {
      throw const ErrorProtocolo(
        'campo',
        'El campo "datos" debe ser un objeto.',
      );
    }
    return Sobre(
      v: v,
      canal: canal,
      sesion: sesion,
      seq: seq,
      tipo: tipo,
      ack: ack as int?,
      datos: datos as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'Sobre($canal/$sesion #$seq $tipo)';
}
