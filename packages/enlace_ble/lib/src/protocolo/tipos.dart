/// Constantes del contrato: canales y tipos de mensaje.
library;

/// Canales lógicos del sobre.
abstract final class Canales {
  /// Partida del juego de pares.
  static const String juego = 'juego';

  /// Transferencia de archivos.
  static const String archivos = 'archivos';

  /// Consulta web por Bluetooth.
  static const String web = 'web';

  /// Mensajes de control (saludo, ping, errores de enlace).
  static const String control = 'control';

  /// Todos los canales válidos.
  static const Set<String> todos = {juego, archivos, web, control};
}

/// Tipos de mensaje (campo `tipo` del sobre).
abstract final class TiposMensaje {
  // Comunes.
  static const String hola = 'HOLA';
  static const String acepta = 'ACEPTA';
  static const String rechaza = 'RECHAZA';
  static const String ack = 'ACK';
  static const String ping = 'PING';
  static const String adios = 'ADIOS';
  static const String error = 'ERROR';

  // Juego.
  static const String partidaNueva = 'PARTIDA_NUEVA';
  static const String jugada = 'JUGADA';
  static const String estado = 'ESTADO';
  static const String reanudar = 'REANUDAR';
  static const String fin = 'FIN';

  // Archivos.
  static const String oferta = 'OFERTA';
  static const String ofertaAcepta = 'OFERTA_ACEPTA';
  static const String ofertaRechaza = 'OFERTA_RECHAZA';
  static const String bloque = 'BLOQUE';
  static const String bloqueAck = 'BLOQUE_ACK';
  static const String cancela = 'CANCELA';
  static const String finArchivo = 'FIN_ARCHIVO';
  static const String resultado = 'RESULTADO';

  // Web.
  static const String peticion = 'PETICION';
  static const String respuesta = 'RESPUESTA';
  static const String errorWeb = 'ERROR_WEB';

  /// Tipos comunes a todos los canales.
  static const Set<String> comunes = {
    hola,
    acepta,
    rechaza,
    ack,
    ping,
    adios,
    error,
  };

  /// Tipos del canal `juego`.
  static const Set<String> deJuego = {
    partidaNueva,
    jugada,
    estado,
    reanudar,
    fin,
  };

  /// Tipos del canal `archivos`.
  static const Set<String> deArchivos = {
    oferta,
    ofertaAcepta,
    ofertaRechaza,
    bloque,
    bloqueAck,
    cancela,
    finArchivo,
    resultado,
  };

  /// Tipos del canal `web`.
  static const Set<String> deWeb = {peticion, respuesta, errorWeb};

  /// Tipos que no esperan ACK (`ACK` y `PING`).
  static const Set<String> noConfiables = {ack, ping};

  /// Indica si un mensaje de [tipo] se confirma con ACK.
  static bool esConfiable(String tipo) => !noConfiables.contains(tipo);
}
