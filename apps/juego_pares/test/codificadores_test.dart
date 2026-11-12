import 'package:flutter_test/flutter_test.dart';
import 'package:juego_pares/datos/codificadores.dart';
import 'package:juego_pares/dominio/configuracion_partida.dart';
import 'package:juego_pares/dominio/error_partida.dart';
import 'package:juego_pares/dominio/estado_partida.dart';
import 'package:juego_pares/dominio/motor_juego.dart';

EstadoPartida partidaDePrueba() {
  final motor = MotorJuego(MotorJuego.crearPartida(
    nivel: 'campus',
    modo: 'relajado',
    semilla: 42,
    configuracion: const ConfiguracionPartida(
      nombreJugador: 'Jesús',
      sonido: false,
      animaciones: true,
      formatoPreferido: 'json',
      tema: 'azul',
    ),
  ));
  // Juega una pareja para que la partida tenga historial.
  final porSimbolo = <String, List<int>>{};
  for (var i = 0; i < motor.partida.tablero.length; i++) {
    porSimbolo.putIfAbsent(motor.partida.tablero[i].simboloId, () => []).add(i);
  }
  final pareja = porSimbolo.values.first;
  motor.seleccionar(pareja[0]);
  motor.seleccionar(pareja[1]);
  return motor.partida.copyWith(etiqueta: 'prueba');
}

void main() {
  group('codificadores', () {
    for (final codificador in <CodificadorPartida>[
      const CodificadorJson(),
      const CodificadorXml(),
      const CodificadorTxt(),
    ]) {
      test('${codificador.extension}: round-trip conserva el estado', () {
        final original = partidaDePrueba();
        final texto = codificador.codificar(original);
        expect(texto, isNotEmpty);
        final leida = codificador.decodificar(texto);
        expect(leida.id, original.id);
        expect(leida.nivel, original.nivel);
        expect(leida.modo, original.modo);
        expect(leida.puntaje, original.puntaje);
        expect(leida.tiempoSegundos, original.tiempoSegundos);
        expect(leida.movimientos.length, original.movimientos.length);
        expect(leida.tablero.length, original.tablero.length);
        expect(leida.tablero.first.simboloId, original.tablero.first.simboloId);
        expect(leida.etiqueta, 'prueba');
        expect(leida.configuracion.nombreJugador, 'Jesús');
        expect(leida.configuracion.tema, 'azul');
      });
    }

    test('archivo vacío se reporta como vacío', () {
      for (final c in <CodificadorPartida>[
        const CodificadorJson(),
        const CodificadorXml(),
        const CodificadorTxt(),
      ]) {
        expect(
          () => c.decodificar('   '),
          throwsA(isA<ErrorPartida>().having((e) => e.tipo, 'tipo', TipoErrorPartida.vacia)),
        );
      }
    });

    test('JSON alterado detecta checksum inválido', () {
      final texto = const CodificadorJson().codificar(partidaDePrueba());
      final alterado = texto.replaceFirst('"puntaje": ', '"puntaje": 9');
      expect(
        () => const CodificadorJson().decodificar(alterado),
        throwsA(isA<ErrorPartida>()),
      );
    });

    test('TXT sin FIN se reporta como incompleto', () {
      final texto = const CodificadorTxt().codificar(partidaDePrueba());
      final truncado = texto.replaceFirst('FIN', '');
      expect(
        () => const CodificadorTxt().decodificar(truncado),
        throwsA(isA<ErrorPartida>().having((e) => e.tipo, 'tipo', TipoErrorPartida.incompleta)),
      );
    });

    test('XML truncado no tumba la app', () {
      final texto = const CodificadorXml().codificar(partidaDePrueba());
      expect(
        () => const CodificadorXml().decodificar(texto.substring(0, texto.length ~/ 2)),
        throwsA(isA<ErrorPartida>()),
      );
    });

    test('versión futura se rechaza', () {
      final mapa = partidaDePrueba().aJson()..['version'] = 99;
      final partida = EstadoPartida.desdeJson(mapa);
      expect(
        () => const CodificadorJson().decodificar(
          const CodificadorJson().codificar(partida),
        ),
        throwsA(isA<ErrorPartida>().having((e) => e.tipo, 'tipo', TipoErrorPartida.version)),
      );
    });

    test('detección por extensión y contenido', () {
      final p = partidaDePrueba();
      expect(detectarCodificador('x.json', '')!.extension, 'json');
      expect(detectarCodificador('x.xml', '')!.extension, 'xml');
      expect(detectarCodificador('x.txt', '')!.extension, 'txt');
      expect(detectarCodificador('sin_extension', '{"a":1}')!.extension, 'json');
      expect(detectarCodificador('sin_extension', '<a/>')!.extension, 'xml');
      expect(detectarCodificador('sin_extension', 'MEMORAMA-IPN\nFIN')!.extension, 'txt');
      expect(detectarCodificador('x.bin', 'binario'), isNull);
      expect(p.id, isNotEmpty);
    });
  });
}
