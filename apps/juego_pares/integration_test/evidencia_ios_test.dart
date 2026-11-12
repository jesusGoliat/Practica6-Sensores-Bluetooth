import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:juego_pares/main.dart' as app;

Future<void> captura(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String nombre,
) async {
  await tester.pump(const Duration(milliseconds: 800));
  await binding.takeScreenshot(nombre);
  // La captura nativa de iOS se completa de forma asíncrona; esperar evita
  // que dos capturas se solapen y que el PNG no corresponda a la pantalla.
  await Future<void>.delayed(const Duration(milliseconds: 500));
}

Future<void> volver(WidgetTester tester) async {
  final boton = find.byType(BackButton);
  if (boton.evaluate().isNotEmpty) {
    await tester.tap(boton.first);
  } else {
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
  }
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Recorrido de evidencia del juego', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await captura(tester, binding, '01-inicio');

    // Nueva partida 4×4 relajada.
    await tester.tap(find.byKey(const Key('btn-jugar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await captura(tester, binding, '02-juego-4x4');

    // Voltear dos cartas.
    await tester.tap(find.byKey(const Key('carta-0')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('carta-1')));
    await tester.pump(const Duration(milliseconds: 500));
    await captura(tester, binding, '03-cartas-volteadas');

    // Pausa.
    await tester.tap(find.byKey(const Key('btn-pausa')));
    await tester.pump(const Duration(milliseconds: 300));
    await captura(tester, binding, '04-pausa');

    // Guardar en JSON (con el juego en pausa para que no haya reloj activo).
    await tester.tap(find.byKey(const Key('btn-guardar-partida')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON (.json)'));
    await tester.pump();
    await tester.tap(find.text('JSON (.json)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn-confirmar-guardado')));
    await tester.pumpAndSettle();
    await captura(tester, binding, '05-partida-guardada');

    // Volver al inicio y abrir la lista de partidas.
    await volver(tester);
    await tester.tap(find.byKey(const Key('nav-partidas')));
    await tester.pumpAndSettle();
    await captura(tester, binding, '06-lista-partidas');

    // Ver el contenido del archivo JSON.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver contenido'));
    await tester.pumpAndSettle();
    await captura(tester, binding, '07-contenido-json');
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    // Ajustes con tema Azul.
    await tester.tap(find.byKey(const Key('nav-ajustes-juego')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ajustes-juego-azul')));
    await tester.pumpAndSettle();
    await captura(tester, binding, '08-ajustes-tema-azul');
  });
}
