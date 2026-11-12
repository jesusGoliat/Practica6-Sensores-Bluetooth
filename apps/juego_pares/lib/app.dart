import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'datos/ajustes_sensores.dart';
import 'datos/estado_juego.dart';
import 'datos/estado_partida_red.dart';
import 'datos/estado_tema_juego.dart';
import 'datos/puente_ble.dart';
import 'datos/repositorio_partida_red.dart';
import 'presentacion/observador_rutas.dart';
import 'presentacion/pantalla_principal_juego.dart';

class JuegoApp extends StatefulWidget {
  const JuegoApp({
    super.key,
    required this.tema,
    required this.juego,
    this.red,
    this.sensores,
  });

  final EstadoTemaJuego tema;
  final EstadoJuego juego;

  /// Estado de la partida por Bluetooth; si es null se crea uno real.
  final EstadoPartidaRed? red;
  final AjustesSensores? sensores;

  @override
  State<JuegoApp> createState() => _JuegoAppState();
}

class _JuegoAppState extends State<JuegoApp> {
  EstadoPartidaRed? _redPropia;
  AjustesSensores? _sensoresPropios;

  EstadoPartidaRed get _red =>
      widget.red ??
      (_redPropia ??= EstadoPartidaRed(
        puente: PuenteBleReal(),
        repositorio: RepositorioPartidaRed.documentos(),
      ));
  AjustesSensores get _sensores => widget.sensores ?? (_sensoresPropios ??= AjustesSensores());

  @override
  void dispose() {
    _redPropia?.dispose();
    _sensoresPropios?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EstadoTemaJuego>.value(value: widget.tema),
        ChangeNotifierProvider<EstadoJuego>.value(value: widget.juego),
        ChangeNotifierProvider<EstadoPartidaRed>.value(value: _red),
        ChangeNotifierProvider<AjustesSensores>.value(value: _sensores),
      ],
      child: Consumer<EstadoTemaJuego>(
        builder: (context, estadoTema, _) => MaterialApp(
          title: 'Pares IPN',
          debugShowCheckedModeBanner: false,
          theme: estadoTema.temaClaro,
          darkTheme: estadoTema.temaOscuro,
          themeMode: estadoTema.modo,
          locale: const Locale('es', 'MX'),
          supportedLocales: const <Locale>[Locale('es', 'MX')],
          navigatorObservers: [observadorRutas],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const PantallaPrincipalJuego(),
        ),
      ),
    );
  }
}
