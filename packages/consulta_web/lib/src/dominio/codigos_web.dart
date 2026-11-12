/// Códigos de error de la consulta web (campo `codigo` de `ERROR_WEB`).
library;

/// Códigos y mensajes en español.
abstract final class CodigosWeb {
  static const String destinoRechazado = 'destino_rechazado';
  static const String limite = 'limite';
  static const String timeout = 'timeout';
  static const String sinInternet = 'sin_internet';
  static const String demasiadoGrande = 'demasiado_grande';
  static const String formatoNoAdmitido = 'formato_no_admitido';
  static const String formato = 'formato';
  static const String red = 'red';

  /// Texto legible para [codigo].
  static String describir(String codigo) => switch (codigo) {
        destinoRechazado => 'Destino no permitido.',
        limite => 'Demasiadas peticiones: máximo 10 por minuto.',
        timeout => 'El servidor tardó más de 10 s en responder.',
        sinInternet => 'El dispositivo A no tiene conexión a Internet.',
        demasiadoGrande => 'La respuesta excede el tamaño máximo permitido.',
        formatoNoAdmitido => 'Formato no admitido.',
        formato => 'Petición mal formada.',
        red => 'Falló la red en el dispositivo A.',
        _ => 'Error: $codigo.',
      };
}
