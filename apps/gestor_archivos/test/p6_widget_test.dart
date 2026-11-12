import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_archivos/app.dart';
import 'package:gestor_archivos/datos/acciones_archivo.dart';
import 'package:gestor_archivos/datos/cache_miniaturas.dart';
import 'package:gestor_archivos/datos/estado_gestor.dart';
import 'package:gestor_archivos/datos/estado_tema.dart';
import 'package:gestor_archivos/datos/repositorio_ubicaciones.dart';
import 'package:gestor_archivos/datos/servicio_archivos.dart';
import 'package:gestor_archivos/datos/servicio_biometria.dart';
import 'package:gestor_archivos/datos/servicios_p6.dart';
import 'package:gestor_archivos/dominio/modelos.dart';
import 'package:path/path.dart' as p;
import 'package:saf/saf.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutenticadorFalso implements Autenticador {
  AutenticadorFalso(this.resultado);
  ResultadoAutenticacion resultado;
  int llamadas = 0;
  @override
  Future<ResultadoAutenticacion> autenticar(String motivo) async {
    llamadas++;
    return resultado;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documentos;
  late EstadoGestor gestor;
  late EstadoTema tema;
  late ServiciosP6 p6;
  late AutenticadorFalso auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    documentos = Directory.systemTemp.createTempSync('p6-widget-');
    final cacheDir = Directory.systemTemp.createTempSync('p6-widget-cache-');
    final ejemplos = Directory(p.join(documentos.path, 'Ejemplos'))..createSync(recursive: true);
    File(p.join(ejemplos.path, 'notas.txt')).writeAsStringSync('Hola IPN');
    final preferencias = PreferenciasApp(prefs);
    final saf = Saf();
    final servicios = Servicios(
      privado: ServicioRutas(origen: OrigenArchivo.privado),
      ios: ServicioRutas(origen: OrigenArchivo.iosSeguro),
      saf: ServicioSaf(saf),
    );
    tema = EstadoTema(preferencias);
    gestor = EstadoGestor(
      servicios: servicios,
      repositorio: RepositorioUbicaciones(prefs),
      preferencias: preferencias,
      cache: CacheMiniaturas(cacheDir),
      documentos: documentos,
      saf: saf,
    );
    await gestor.iniciar();
    auth = AutenticadorFalso(ResultadoAutenticacion.cancelado);
    p6 = ServiciosP6.crear(
      preferencias: preferencias,
      documentos: documentos,
      soporte: Directory.systemTemp.createTempSync('p6-soporte-'),
      servicioPrivado: servicios.privado,
      autenticador: auth,
    );
    await p6.ajustes.setSacudir(false);
  });

  tearDown(() => documentos.deleteSync(recursive: true));

  Widget app() => GestorApp(
      tema: tema, gestor: gestor, acciones: AccionesArchivo(documentos), documentos: documentos, p6: p6);

  void telefono(WidgetTester t) {
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Future<void> eliminarNotas(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('entrada-Ejemplos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menu-notas.txt')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    // Diálogo de confirmación.
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();
  }

  File notas() => File(p.join(documentos.path, 'Ejemplos', 'notas.txt'));

  testWidgets('BIO: cancelar la autenticación NO elimina', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await eliminarNotas(tester);
    expect(auth.llamadas, 1);
    expect(notas().existsSync(), isTrue);
    expect(find.textContaining('cancelada'), findsOneWidget);
  });

  testWidgets('BIO: sin bloqueo o fallo tampoco elimina; con éxito sí', (tester) async {
    telefono(tester);
    auth.resultado = ResultadoAutenticacion.sinBloqueo;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await eliminarNotas(tester);
    expect(notas().existsSync(), isTrue);
    expect(find.textContaining('bloqueo de pantalla'), findsOneWidget);
  });

  testWidgets('BIO: con éxito elimina', (tester) async {
    telefono(tester);
    auth.resultado = ResultadoAutenticacion.exito;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await eliminarNotas(tester);
    expect(notas().existsSync(), isFalse);
  });

  testWidgets('Bóveda: sin autenticar no muestra datos; con éxito lista y vuelve a bloquear',
      (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn-mas')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bóveda'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('btn-desbloquear')), findsOneWidget);
    expect(find.byKey(const Key('boveda-nota_privada.txt')), findsNothing);
    expect(find.byKey(const Key('nota-biometria')), findsOneWidget);
    expect(p6.boveda.desbloqueada, isFalse);

    auth.resultado = ResultadoAutenticacion.noDisponible('Sin hardware');
    await tester.tap(find.byKey(const Key('btn-desbloquear')));
    await tester.pumpAndSettle();
    expect(find.text('Sin hardware'), findsOneWidget);

    auth.resultado = ResultadoAutenticacion.exito;
    // La creación de la carpeta usa E/S real: se hace fuera del reloj falso.
    await tester.runAsync(p6.boveda.asegurar);
    await tester.tap(find.byKey(const Key('btn-desbloquear')));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boveda-nota_privada.txt')), findsOneWidget);

    // Segundo plano -> bloquea.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(p6.boveda.desbloqueada, isFalse);
    // En segundo plano no se dibujan cuadros; al volver ya no hay datos.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('boveda-nota_privada.txt')), findsNothing);
    expect(find.byKey(const Key('btn-desbloquear')), findsOneWidget);
  });

  testWidgets('el explorador no muestra la carpeta protegido/', (tester) async {
    telefono(tester);
    Directory(p.join(documentos.path, 'protegido')).createSync();
    await gestor.recargar();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('entrada-protegido')), findsNothing);
    expect(find.byKey(const Key('entrada-Ejemplos')), findsOneWidget);
  });

  testWidgets('Compartir: pestañas y cola acotada a 5', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final t = p6.transferencias;
    final errores = <String?>[
      for (var i = 0; i < 6; i++) t.encolarBytes('a$i.txt', 10, () async => throw StateError('no'))
    ];
    expect(errores.where((e) => e == null).length, 5);
    expect(errores.last, contains('cola está llena'));
    t.consumirAviso();
    await tester.tap(find.byKey(const Key('nav-compartir')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('tab-enviar')), findsOneWidget);
    expect(find.text('Cola (5/5)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-historial')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chip-pendiente')), findsWidgets);
    await tester.tap(find.byKey(const Key('tab-recibir')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('switch-recibir')), findsOneWidget);
    expect(find.textContaining('desde el inicio'), findsOneWidget);
  });

  testWidgets('Sacudir con sensores simulados actualiza el listado', (tester) async {
    telefono(tester);
    await p6.ajustes.setSacudir(true);
    await p6.ajustes.setSimulados(true);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 500));
    p6.sensores.inyectarSacudida();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('Listado actualizado (sacudida)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ajustes: diagnóstico y sacudir', (tester) async {
    telefono(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-ajustes')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('ajustes-alterar-bloque')), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Alterar un bloque (prueba de integridad)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ajustes-alterar-bloque')));
    await tester.pump();
    expect(p6.ajustes.alterarBloque, isTrue);
    expect(find.text('Usar sensores simulados'), findsOneWidget);
  });
}
