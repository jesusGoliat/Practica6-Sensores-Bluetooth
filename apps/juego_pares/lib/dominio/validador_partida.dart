import 'carta.dart';
import 'error_partida.dart';
import 'estado_partida.dart';

/// Valida que una partida sea coherente antes de mostrarla o cargarla.
/// Un archivo dañado produce un mensaje legible, nunca una excepción sin
/// control ni la pérdida de las demás partidas.
abstract final class ValidadorPartida {
  static void validar(EstadoPartida partida) {
    if (partida.version > EstadoPartida.versionActual) {
      throw ErrorPartida(
        TipoErrorPartida.version,
        'La partida fue creada por una versión más nueva de la app (versión ${partida.version}).',
      );
    }
    if (partida.id.trim().isEmpty) {
      throw const ErrorPartida(TipoErrorPartida.incompleta, 'La partida no tiene identificador.');
    }
    if ((partida.filas != 4 && partida.filas != 6) || partida.columnas != partida.filas) {
      throw const ErrorPartida(
        TipoErrorPartida.estadoInconsistente,
        'El tamaño del tablero no es válido (debe ser 4×4 o 6×6).',
      );
    }
    if (partida.tablero.length != partida.filas * partida.columnas) {
      throw const ErrorPartida(
        TipoErrorPartida.incompleta,
        'El tablero está incompleto: faltan cartas.',
      );
    }
    final conteo = <String, int>{};
    for (final carta in partida.tablero) {
      if (carta.simboloId.isEmpty) {
        throw const ErrorPartida(TipoErrorPartida.formato, 'Hay una carta sin símbolo.');
      }
      conteo[carta.simboloId] = (conteo[carta.simboloId] ?? 0) + 1;
    }
    for (final entrada in conteo.entries) {
      if (entrada.value != 2) {
        throw ErrorPartida(
          TipoErrorPartida.estadoInconsistente,
          'El símbolo «${entrada.key}» no forma una pareja (${entrada.value} cartas).',
        );
      }
    }
    if (partida.puntaje < 0 || partida.tiempoSegundos < 0 || partida.racha < 0 || partida.mejorRacha < 0) {
      throw const ErrorPartida(
        TipoErrorPartida.estadoInconsistente,
        'La puntuación o el tiempo tienen valores negativos.',
      );
    }
    for (final movimiento in partida.movimientos) {
      if (movimiento.indiceA < 0 ||
          movimiento.indiceB < 0 ||
          movimiento.indiceA >= partida.tablero.length ||
          movimiento.indiceB >= partida.tablero.length ||
          movimiento.indiceA == movimiento.indiceB) {
        throw const ErrorPartida(
          TipoErrorPartida.estadoInconsistente,
          'El historial contiene posiciones de carta inválidas.',
        );
      }
    }
    final todasEmparejadas =
        partida.tablero.every((c) => c.estado == EstadoCarta.emparejada);
    if (partida.victoria && !todasEmparejadas) {
      throw const ErrorPartida(
        TipoErrorPartida.estadoInconsistente,
        'La partida dice estar ganada pero quedan cartas sin emparejar.',
      );
    }
    if (!partida.terminada && todasEmparejadas && partida.tablero.isNotEmpty) {
      throw const ErrorPartida(
        TipoErrorPartida.estadoInconsistente,
        'Todas las cartas están emparejadas pero la partida no está marcada como terminada.',
      );
    }
  }
}
