import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saf/saf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selector_carpetas_ios/selector_carpetas_ios.dart';

import 'app.dart';
import 'datos/acciones_archivo.dart';
import 'datos/cache_miniaturas.dart';
import 'datos/estado_gestor.dart';
import 'datos/estado_tema.dart';
import 'datos/repositorio_ubicaciones.dart';
import 'datos/semilla_archivos.dart';
import 'datos/servicio_archivos.dart';
import 'dominio/modelos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final documentos = await getApplicationDocumentsDirectory();
  final temporales = await getTemporaryDirectory();

  final preferencias = PreferenciasApp(prefs);
  final repo = RepositorioUbicaciones(prefs);
  final cache = CacheMiniaturas(temporales);
  final saf = Saf();

  await SemillaArchivos(documentos).crearSiFalta(preferencias);

  final servicios = Servicios(
    privado: ServicioRutas(origen: OrigenArchivo.privado),
    ios: ServicioRutas(origen: OrigenArchivo.iosSeguro),
    saf: ServicioSaf(saf),
  );

  final tema = EstadoTema(preferencias);
  final gestor = EstadoGestor(
    servicios: servicios,
    repositorio: repo,
    preferencias: preferencias,
    cache: cache,
    documentos: documentos,
    saf: saf,
    selectorIos: SelectorCarpetasIos(),
  );
  await gestor.iniciar();

  runApp(GestorApp(
    tema: tema,
    gestor: gestor,
    acciones: AccionesArchivo(temporales),
    documentos: documentos,
  ));
}

/// Punto de entrada reutilizable por las pruebas de integración.
Future<void> arrancarParaPruebas({
  required EstadoTema tema,
  required EstadoGestor gestor,
  required AccionesArchivo acciones,
  required Directory documentos,
}) async {
  runApp(GestorApp(
    tema: tema,
    gestor: gestor,
    acciones: acciones,
    documentos: documentos,
  ));
}
