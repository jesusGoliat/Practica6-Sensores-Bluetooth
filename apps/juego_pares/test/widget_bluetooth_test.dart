import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_pares/app.dart';
import 'package:juego_pares/datos/ajustes_sensores.dart';
import 'package:juego_pares/datos/estado_juego.dart';
import 'package:juego_pares/datos/estado_partida_red.dart';
import 'package:juego_pares/datos/estado_tema_juego.dart';
import 'package:juego_pares/datos/preferencias_juego.dart';
import 'package:juego_pares/datos/puente_ble.dart';
import 'package:juego_pares/datos/repositorio_partida_red.dart';
import 'package:juego_pares/datos/repositorio_partidas.dart';
import 'package:juego_pares/datos/sonido_service.dart';
import 'package:juego_pares/dominio/carta.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory temp;
  late EstadoJuego juego;
  late EstadoTemaJuego tema;
  late EstadoPartidaRed red;
  late AjustesSensores sensores;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    docs = Directory.systemTemp.createTempSync('p6j-widget-');
    temp = Directory.systemTemp.createTempSync('p6j-widget-tmp-');
    final preferencias = PreferenciasJuego(prefs);
    tema = EstadoTemaJuego(preferencias);
    juego = EstadoJuego(
      repositorio: RepositorioPartidas(Directory('${docs.path}/partidas')),
      preferencias: preferencias,
      sonido: SonidoService(),
      temporales: temp,
    );
    await juego.iniciar();
    red = EstadoPartidaRed(
      puente: PuenteBleReal(),
      repositorio: RepositorioPartidaRed.enDirectorio(Directory('${docs.path}/red')),
    );
    sensores = AjustesSensores();
  });

  tearDown(() {
    juego.dispose();
    red.dispose();
    docs.deleteSync(recursive: true);
    temp.deleteSync(recursive: true);
  });

  void telefono(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app() => JuegoApp(tema: tema, juego: juego, red: red, sensores: sensores);

  testWidgets('el destino Bluetooth muestra la elección de rol', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-bluetooth')));
    await tester.pumpAndSettle();
    expect(find.text('Anfitrión'), findsOneWidget);
    expect(find.text('Unirse'), findsOneWidget);
    expect(find.byKey(const Key('rol-anfitrion')), findsOneWidget);
    expect(find.byKey(const Key('rol-invitado')), findsOneWidget);
    expect(find.text('Registro de eventos (0)'), findsOneWidget);
  });

  testWidgets('el control por movimiento simulado mueve el cursor y voltea una carta',
      (tester) async {
    telefono(tester);
    sensores.usarSimulados(true);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn-jugar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('cursor-movimiento')), findsNothing);

    await tester.tap(find.byKey(const Key('switch-movimiento')));
    await tester.pump();
    expect(find.byKey(const Key('cursor-movimiento')), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Inclinación a la derecha (cursor 0 -> 1) y giro: voltea la carta 1.
    expect(juego.partida!.tablero[1].estado, EstadoCarta.visible);

    await tester.tap(find.byKey(const Key('switch-movimiento')));
    await tester.pump();
    expect(find.byKey(const Key('cursor-movimiento')), findsNothing);
    juego.detenerTemporizadores();
    await tester.pump(const Duration(seconds: 1));
  });
}
