import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'datos/acciones_archivo.dart';
import 'datos/estado_gestor.dart';
import 'datos/estado_tema.dart';
import 'presentacion/pantalla_principal.dart';

class GestorApp extends StatelessWidget {
  const GestorApp({
    super.key,
    required this.tema,
    required this.gestor,
    required this.acciones,
    required this.documentos,
  });

  final EstadoTema tema;
  final EstadoGestor gestor;
  final AccionesArchivo acciones;
  final Directory documentos;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EstadoTema>.value(value: tema),
        ChangeNotifierProvider<EstadoGestor>.value(value: gestor),
        Provider<AccionesArchivo>.value(value: acciones),
        Provider<Directory>.value(value: documentos),
      ],
      child: Consumer<EstadoTema>(
        builder: (context, estadoTema, _) {
          return MaterialApp(
            title: 'Archivos IPN',
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
            home: const PantallaPrincipal(),
          );
        },
      ),
    );
  }
}
