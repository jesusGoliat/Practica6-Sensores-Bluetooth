import 'dart:io';

import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_archivos/app.dart';
import 'package:gestor_archivos/datos/acciones_archivo.dart';
import 'package:gestor_archivos/datos/cache_miniaturas.dart';
import 'package:gestor_archivos/datos/estado_gestor.dart';
import 'package:gestor_archivos/datos/estado_tema.dart';
import 'package:gestor_archivos/datos/repositorio_ubicaciones.dart';
import 'package:gestor_archivos/datos/servicio_archivos.dart';
import 'package:gestor_archivos/dominio/modelos.dart';
import 'package:path/path.dart' as p;
import 'package:saf/saf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentos;
  late EstadoGestor gestor;
  late EstadoTema tema;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    documentos = Directory.systemTemp.createTempSync('p4-widget-');
    final cacheDir = Directory.systemTemp.createTempSync('p4-widget-cache-');
    final ejemplos = Directory(p.join(documentos.path, 'Ejemplos'));
    await ejemplos.create(recursive: true);
    await File(p.join(ejemplos.path, 'datos.json')).writeAsString('{"a": 1}');
    await File(p.join(ejemplos.path, 'notas.txt')).writeAsString('Hola IPN');

    final preferencias = PreferenciasApp(prefs);
    final repo = RepositorioUbicaciones(prefs);
    final saf = Saf();
    final servicios = Servicios(
      privado: ServicioRutas(origen: OrigenArchivo.privado),
      ios: ServicioRutas(origen: OrigenArchivo.iosSeguro),
      saf: ServicioSaf(saf),
    );
    tema = EstadoTema(preferencias);
    gestor = EstadoGestor(
      servicios: servicios,
      repositorio: repo,
      preferencias: preferencias,
      cache: CacheMiniaturas(cacheDir),
      documentos: documentos,
      saf: saf,
    );
    await gestor.iniciar();
  });

  tearDown(() {
    documentos.deleteSync(recursive: true);
  });

  Widget app() => GestorApp(
        tema: tema,
        gestor: gestor,
        acciones: AccionesArchivo(documentos),
        documentos: documentos,
      );

  void telefono(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('muestra el explorador y la navegación principal', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Archivos IPN'), findsOneWidget);
    expect(find.text(T.explorador), findsWidgets);
    expect(find.byKey(const Key('raiz-privado')), findsOneWidget);
    expect(find.byKey(const Key('entrada-Ejemplos')), findsOneWidget);
  });

  testWidgets('favoritos vacío y ajustes con temas', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-favoritos')));
    await tester.pumpAndSettle();
    expect(find.text(T.sinFavoritos), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-ajustes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ajustes-tema-guinda')), findsOneWidget);
    expect(find.byKey(const Key('ajustes-tema-azul')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ajustes-tema-azul')));
    await tester.pumpAndSettle();
    expect(tema.visual, TemaVisual.azul);
  });

  testWidgets('abre una carpeta y muestra su contenido', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('entrada-Ejemplos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entrada-datos.json')), findsOneWidget);
    expect(find.byKey(const Key('entrada-notas.txt')), findsOneWidget);
    expect(find.byKey(const Key('breadcrumbs')), findsOneWidget);
  });

  testWidgets('se adapta a una pantalla angosta sin overflow', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Archivos IPN'), findsOneWidget);
  });
}
