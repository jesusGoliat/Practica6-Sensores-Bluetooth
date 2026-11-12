import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'datos/acciones_archivo.dart';
import 'datos/estado_gestor.dart';
import 'datos/ajustes_app.dart';
import 'datos/boveda.dart';
import 'datos/estado_tema.dart';
import 'datos/servicio_biometria.dart';
import 'datos/servicio_sensores.dart';
import 'datos/servicios_p6.dart';
import 'datos/transferencia/estado_transferencias.dart';
import 'presentacion/pantalla_principal.dart';

class GestorApp extends StatelessWidget {
  const GestorApp({
    super.key,
    required this.tema,
    required this.gestor,
    required this.acciones,
    required this.documentos,
    required this.p6,
  });

  final EstadoTema tema;
  final EstadoGestor gestor;
  final AccionesArchivo acciones;
  final Directory documentos;
  final ServiciosP6 p6;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EstadoTema>.value(value: tema),
        ChangeNotifierProvider<EstadoGestor>.value(value: gestor),
        Provider<AccionesArchivo>.value(value: acciones),
        Provider<Directory>.value(value: documentos),
        ChangeNotifierProvider<AjustesApp>.value(value: p6.ajustes),
        ChangeNotifierProvider<EstadoTransferencias>.value(value: p6.transferencias),
        ChangeNotifierProvider<EstadoBoveda>.value(value: p6.boveda),
        Provider<Autenticador>.value(value: p6.autenticador),
        Provider<ServicioSensores>.value(value: p6.sensores),
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
