import 'dart:io';

import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_pares/app.dart';
import 'package:juego_pares/datos/estado_juego.dart';
import 'package:juego_pares/datos/estado_tema_juego.dart';
import 'package:juego_pares/datos/preferencias_juego.dart';
import 'package:juego_pares/datos/repositorio_partidas.dart';
import 'package:juego_pares/datos/sonido_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory temp;
  late EstadoJuego juego;
  late EstadoTemaJuego tema;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    docs = Directory.systemTemp.createTempSync('p4j-widget-');
    temp = Directory.systemTemp.createTempSync('p4j-widget-tmp-');
    final preferencias = PreferenciasJuego(prefs);
    tema = EstadoTemaJuego(preferencias);
    juego = EstadoJuego(
      repositorio: RepositorioPartidas(Directory('${docs.path}/partidas')),
      preferencias: preferencias,
      sonido: SonidoService(),
      temporales: temp,
    );
    await juego.iniciar();
  });

  tearDown(() {
    juego.dispose();
    docs.deleteSync(recursive: true);
    temp.deleteSync(recursive: true);
  });

  Widget app() => JuegoApp(tema: tema, juego: juego);

  void telefono(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('inicio, navegación y ajustes', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Pares Politécnicos'), findsOneWidget);
    expect(find.byKey(const Key('btn-jugar')), findsOneWidget);
    expect(find.text(T.jugar), findsWidgets);

    await tester.tap(find.byKey(const Key('nav-partidas')));
    await tester.pumpAndSettle();
    expect(find.text(T.sinPartidas), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-ajustes-juego')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('switch-sonido')), findsOneWidget);
    expect(find.byKey(const Key('ajustes-juego-azul')), findsOneWidget);
  });

  testWidgets('inicia una partida, pausa y reanuda', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('btn-jugar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('btn-pausa')), findsOneWidget);
    expect(find.byKey(const Key('carta-0')), findsOneWidget);
    expect(find.byKey(const Key('carta-15')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-pausa')));
    await tester.pump();
    expect(find.byKey(const Key('btn-reanudar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-reanudar')));
    await tester.pump();
    expect(find.byKey(const Key('btn-reanudar')), findsNothing);
    juego.detenerTemporizadores();
  });

  testWidgets('cambia al tema Azul y modo oscuro', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-ajustes-juego')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ajustes-juego-azul')));
    await tester.pumpAndSettle();
    expect(tema.visual, TemaVisual.azul);
  });
}
