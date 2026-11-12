import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'datos/estado_juego.dart';
import 'datos/estado_tema_juego.dart';
import 'presentacion/pantalla_principal_juego.dart';

class JuegoApp extends StatelessWidget {
  const JuegoApp({super.key, required this.tema, required this.juego});

  final EstadoTemaJuego tema;
  final EstadoJuego juego;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EstadoTemaJuego>.value(value: tema),
        ChangeNotifierProvider<EstadoJuego>.value(value: juego),
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
