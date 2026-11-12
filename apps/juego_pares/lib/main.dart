import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'datos/estado_juego.dart';
import 'datos/estado_tema_juego.dart';
import 'datos/preferencias_juego.dart';
import 'datos/repositorio_partidas.dart';
import 'datos/sonido_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final documentos = await getApplicationDocumentsDirectory();
  final temporales = await getTemporaryDirectory();
  final preferencias = PreferenciasJuego(prefs);
  final tema = EstadoTemaJuego(preferencias);
  final sonido = SonidoService(habilitado: preferencias.sonido);
  final repo = RepositorioPartidas(Directory(p.join(documentos.path, 'partidas')));
  await repo.asegurar();
  final juego = EstadoJuego(
    repositorio: repo,
    preferencias: preferencias,
    sonido: sonido,
    temporales: temporales,
  );
  await juego.iniciar();
  runApp(JuegoApp(tema: tema, juego: juego));
}

/// Variante usada por las pruebas de integración.
Future<void> arrancarParaPruebas({
  required EstadoTemaJuego tema,
  required EstadoJuego juego,
}) async {
  runApp(JuegoApp(tema: tema, juego: juego));
}
