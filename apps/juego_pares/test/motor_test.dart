import 'package:flutter_test/flutter_test.dart';
import 'package:juego_pares/dominio/configuracion_partida.dart';
import 'package:juego_pares/dominio/motor_juego.dart';

void main() {
  MotorJuego nuevo({String modo = 'relajado'}) => MotorJuego(MotorJuego.crearPartida(
        nivel: 'campus',
        modo: modo,
        semilla: 7,
        configuracion: const ConfiguracionPartida(),
      ));

  List<List<int>> parejas(MotorJuego motor) {
    final mapa = <String, List<int>>{};
    for (var i = 0; i < motor.partida.tablero.length; i++) {
      mapa.putIfAbsent(motor.partida.tablero[i].simboloId, () => []).add(i);
    }
    return mapa.values.toList();
  }

  test('tablero 4×4 con pares y sin cartas visibles', () {
    final motor = nuevo();
    expect(motor.partida.tablero.length, 16);
    expect(motor.partida.filas, 4);
    expect(motor.partida.tablero.every((c) => c.estado.name == 'oculta'), isTrue);
    for (final p in parejas(motor)) {
      expect(p.length, 2);
    }
  });

  test('acierto suma puntos, racha y registra movimiento', () {
    final motor = nuevo();
    final par = parejas(motor).first;
    motor.seleccionar(par[0]);
    final r = motor.seleccionar(par[1]);
    expect(r, isNotNull);
    expect(r!.acierto, isTrue);
    expect(motor.partida.puntaje, greaterThanOrEqualTo(100));
    expect(motor.partida.racha, 1);
    expect(motor.partida.movimientos.length, 1);
    expect(motor.partida.movimientos.first.acierto, isTrue);
    expect(motor.partida.emparejadas, 2);
  });

  test('fallo resta puntos, corta racha y oculta las cartas', () {
    final motor = nuevo();
    final pares = parejas(motor);
    final a = pares[0][0];
    final b = pares[1][0];
    motor.seleccionar(a);
    final r = motor.seleccionar(b);
    expect(r!.acierto, isFalse);
    expect(r.esperandoOcultar, isTrue);
    expect(motor.partida.racha, 0);
    expect(motor.visibles.length, 2);
    motor.ocultarPendientes();
    expect(motor.visibles, isEmpty);
    expect(motor.partida.movimientos.single.acierto, isFalse);
  });

  test('completar el tablero termina la partida con bonificación', () {
    final motor = nuevo();
    for (final par in parejas(motor)) {
      motor.seleccionar(par[0]);
      motor.seleccionar(par[1]);
    }
    expect(motor.partida.terminada, isTrue);
    expect(motor.partida.victoria, isTrue);
    expect(motor.partida.emparejadas, 16);
    expect(motor.partida.puntaje, greaterThan(0));
    expect(motor.partida.movimientos.length, 8);
  });

  test('contrarreloj termina al agotarse el límite', () {
    final motor = nuevo(modo: 'contrarreloj');
    expect(motor.actualizarTiempo(91), isTrue);
    expect(motor.partida.terminada, isTrue);
    expect(motor.partida.perdida, isTrue);
    expect(motor.partida.restante, 0);
  });

  test('no permite una tercera carta mientras hay dos visibles', () {
    final motor = nuevo();
    final pares = parejas(motor);
    motor.seleccionar(pares[0][0]);
    motor.seleccionar(pares[1][0]);
    final tercera = motor.seleccionar(pares[2][0]);
    expect(tercera, isNull);
  });

  test('el tiempo de un modo relajado no termina la partida', () {
    final motor = nuevo();
    expect(motor.actualizarTiempo(9999), isFalse);
    expect(motor.partida.terminada, isFalse);
  });
}
