import 'package:flutter/material.dart';

/// Los dos temas institucionales solicitados por la práctica.
enum TemaVisual { guinda, azul }

abstract final class PaletaApp {
  /// Guinda representativo del IPN.
  static const Color guinda = Color(0xFF6C1D45);

  /// Azul representativo de la ESCOM.
  static const Color azul = Color(0xFF003B5C);

  static Color semilla(TemaVisual visual) =>
      visual == TemaVisual.guinda ? guinda : azul;

  static String nombre(TemaVisual visual) =>
      visual == TemaVisual.guinda ? 'Guinda IPN' : 'Azul ESCOM';
}

/// Construye el tema Material 3 para el tema visual y el brillo indicados.
///
/// El brillo lo decide la app: por defecto sigue al sistema (ThemeMode.system),
/// pero el usuario puede forzar claro u oscuro sin perder la paleta elegida.
ThemeData construirTema({
  required TemaVisual visual,
  required Brightness brillo,
}) {
  final esquema = ColorScheme.fromSeed(
    seedColor: PaletaApp.semilla(visual),
    brightness: brillo,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    brightness: brillo,
    visualDensity: VisualDensity.standard,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: esquema.surface,
      foregroundColor: esquema.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 10,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
