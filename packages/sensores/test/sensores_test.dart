import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensores/sensores.dart';

LecturaSensor lec(double x, double y, double z,
        {TipoSensor tipo = TipoSensor.acelerometro, int ms = 0}) =>
    LecturaSensor(
        tipo: tipo,
        x: x,
        y: y,
        z: z,
        instante: DateTime(2026, 1, 1).add(Duration(milliseconds: ms)),
        origen: OrigenLectura.simulada);

void main() {
  group('LecturaSensor', () {
    test('unidades y magnitud', () {
      expect(lec(3, 4, 0).unidad, 'm/s²');
      expect(lec(0, 0, 2, tipo: TipoSensor.giroscopio).unidad, 'rad/s');
      expect(lec(3, 4, 0).magnitud, closeTo(5, 1e-9));
    });
  });

  group('ControladorSensor', () {
    late StreamController<List<double>> ctl;
    late int escuchas, cancelaciones;
    ControladorSensor crear({Duration limite = const Duration(seconds: 2)}) {
      escuchas = 0;
      cancelaciones = 0;
      ctl = StreamController<List<double>>.broadcast(
          onListen: () => escuchas++, onCancel: () => cancelaciones++);
      return ControladorSensor(
          FuenteSimulada(TipoSensor.acelerometro, flujo: ctl.stream),
          limiteSinDatos: limite);
    }

    test('valores normales y origen simulado', () async {
      final c = crear();
      await c.iniciar();
      ctl.add([0.1, 9.8, 0.3]);
      await Future<void>.delayed(Duration.zero);
      expect(c.estado, EstadoSensor.escuchando);
      expect(c.ultima!.y, 9.8);
      expect(c.ultima!.origen, OrigenLectura.simulada);
      expect(c.fuente.origen, OrigenLectura.simulada);
      c.dispose();
    });

    test('valores extremos y NaN/infinito no fallan', () async {
      final c = crear();
      await c.iniciar();
      ctl.add([1000, -1000, 1000]);
      await Future<void>.delayed(Duration.zero);
      expect(c.ultima!.x, 1000);
      ctl.add([double.nan, 1, 1]);
      ctl.add([double.infinity, 1, 1]);
      await Future<void>.delayed(Duration.zero);
      expect(c.ultima!.x, 1000);
      expect(c.estado, EstadoSensor.escuchando);
      expect(c.bitacora.where((e) => e.descripcion.startsWith('Error')),
          hasLength(1));
      c.dispose();
    });

    test('ausente', () async {
      final c = ControladorSensor(
          FuenteSimulada(TipoSensor.giroscopio, ausente: true));
      await c.iniciar();
      expect(c.estado, EstadoSensor.ausente);
      expect(c.bitacora.last.descripcion, 'Sensor ausente');
      c.dispose();
    });

    test('sinDatos tras el límite y recuperación', () {
      fakeAsync((fa) {
        final c = crear(limite: const Duration(seconds: 1));
        c.iniciar();
        fa.flushMicrotasks();
        expect(c.estado, EstadoSensor.escuchando);
        fa.elapse(const Duration(milliseconds: 1100));
        expect(c.estado, EstadoSensor.sinDatos);
        ctl.add([1, 2, 3]);
        fa.flushMicrotasks();
        expect(c.estado, EstadoSensor.escuchando);
        c.dispose();
      });
    });

    test('pausar cancela y reanudar vuelve a escuchar', () async {
      final c = crear();
      await c.iniciar();
      expect(escuchas, 1);
      c.pausar();
      await Future<void>.delayed(Duration.zero);
      expect(c.estado, EstadoSensor.pausado);
      expect(cancelaciones, 1);
      expect(c.suscrito, isFalse);
      c.reanudar();
      expect(escuchas, 2);
      expect(c.estado, EstadoSensor.escuchando);
      c.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(cancelaciones, 2);
    });

    test('error del flujo no lanza y se registra', () async {
      final c = crear();
      await c.iniciar();
      ctl.addError(StateError('x'));
      await Future<void>.delayed(Duration.zero);
      expect(c.estado, EstadoSensor.error);
      c.dispose();
    });

    test('bitácora limitada a 50', () async {
      final c = crear();
      await c.iniciar();
      for (var i = 0; i < 40; i++) {
        c.pausar();
        c.reanudar();
      }
      expect(c.bitacora.length, 50);
      c.dispose();
    });
  });

  group('Detectores', () {
    test('sacudida: umbral y enfriamiento', () {
      final d = DetectorSacudida();
      expect(d.procesar(lec(0, 9.8, 0)), isFalse);
      expect(d.procesar(lec(30, 9.8, 0, ms: 0)), isTrue);
      expect(d.procesar(lec(30, 9.8, 0, ms: 500)), isFalse);
      expect(d.procesar(lec(30, 9.8, 0, ms: 900)), isTrue);
      expect(d.procesar(lec(double.nan, 0, 0, ms: 5000)), isFalse);
    });

    test('inclinación: direcciones y repetición', () {
      final d = DetectorInclinacion();
      expect(d.procesar(lec(1, 1, 9)), Direccion.ninguna);
      expect(d.procesar(lec(5, 0, 9, ms: 0)), Direccion.izquierda);
      expect(d.procesar(lec(5, 0, 9, ms: 100)), Direccion.ninguna);
      expect(d.procesar(lec(-5, 0, 9, ms: 400)), Direccion.derecha);
      expect(d.procesar(lec(0, 5, 9, ms: 800)), Direccion.arriba);
      expect(d.procesar(lec(0, -5, 9, ms: 1200)), Direccion.abajo);
    });

    test('giro: umbral y enfriamiento', () {
      final d = DetectorGiro();
      final g = TipoSensor.giroscopio;
      expect(d.procesar(lec(0, 0, 3, tipo: g)), isFalse);
      expect(d.procesar(lec(0, 0, -5, tipo: g, ms: 0)), isTrue);
      expect(d.procesar(lec(0, 5, 0, tipo: g, ms: 300)), isFalse);
      expect(d.procesar(lec(0, 5, 0, tipo: g, ms: 900)), isTrue);
      expect(d.procesar(lec(0, 0, 9)), isFalse); // acelerómetro ignorado
    });
  });

  group('UI', () {
    testWidgets('PanelSensor muestra unidad y SIMULADA', (t) async {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: PanelSensor(
                  tipo: TipoSensor.acelerometro,
                  estado: EstadoSensor.escuchando,
                  lectura: lec(1, 2.345, 3)))));
      expect(find.text('SIMULADA'), findsOneWidget);
      expect(find.text('FÍSICA'), findsNothing);
      expect(find.text('y: 2.35 m/s²'), findsOneWidget);
      expect(find.text('Instante: 00:00:00.000'), findsOneWidget);
      expect(find.text('Estado: Escuchando'), findsOneWidget);
    });

    testWidgets('PantallaSensores inicia y detiene', (t) async {
      final a = ControladorSensor(FuenteSimulada(TipoSensor.acelerometro,
          ausente: true));
      final g = ControladorSensor(
          FuenteSimulada(TipoSensor.giroscopio, ausente: true));
      await t.pumpWidget(MaterialApp(
          home: PantallaSensores(acelerometro: a, giroscopio: g)));
      await t.tap(find.byType(Switch));
      await t.pump();
      await t.pump();
      expect(a.estado, EstadoSensor.ausente);
      expect(find.text('Sensor ausente'), findsWidgets);
      await t.pumpWidget(const SizedBox());
      a.dispose();
      g.dispose();
    });
  });
}
