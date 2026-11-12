import 'dart:io';

import 'package:path/path.dart' as p;

import 'error_archivo.dart';

/// Validaciones de seguridad antes de leer o escribir.
abstract final class ValidadorRutas {
  static const Set<String> _reservadosWindows = <String>{
    'CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'LPT1', 'LPT2',
  };

  /// Nombre simple de archivo o carpeta, sin separadores ni traversal.
  static bool nombreValido(String nombre) {
    final limpio = nombre.trim();
    if (limpio.isEmpty || limpio.length > 255) return false;
    if (limpio == '.' || limpio == '..') return false;
    if (limpio.contains('/') || limpio.contains(r'\')) return false;
    if (limpio.contains('\u0000')) return false;
    // Caracteres problemáticos en proveedores de documentos.
    if (RegExp(r'[<>:"|?*]').hasMatch(limpio)) return false;
    final base = limpio.split('.').first.toUpperCase();
    if (_reservadosWindows.contains(base)) return false;
    return true;
  }

  static void exigirNombreValido(String nombre) {
    if (!nombreValido(nombre)) {
      throw const ErrorArchivo(
        TipoErrorArchivo.nombreInvalido,
        'El nombre no es válido. No uses / \\ : * ? " < > | ni dejes el campo vacío.',
      );
    }
  }

  /// Comprueba que una ruta esté dentro de la raíz autorizada.
  static bool dentroDe(String ruta, String raiz) {
    final rutaNormal = p.normalize(p.absolute(ruta));
    final raizNormal = p.normalize(p.absolute(raiz));
    if (rutaNormal == raizNormal) return true;
    if (!rutaNormal.startsWith('$raizNormal${p.separator}')) return false;
    // Resolver symlinks cuando sea posible para evitar escapes.
    try {
      final real = File(rutaNormal).resolveSymbolicLinksSync();
      final realRaiz = Directory(raizNormal).resolveSymbolicLinksSync();
      return real == realRaiz || real.startsWith('$realRaiz${p.separator}');
    } on FileSystemException {
      // Si aún no existe (por ejemplo, un destino nuevo), basta la comparación
      // textual: el padre ya fue validado por la misma función.
      return true;
    }
  }

  static void exigirDentroDe(String ruta, String raiz) {
    if (!dentroDe(ruta, raiz)) {
      throw const ErrorArchivo(
        TipoErrorArchivo.destinoNoAutorizado,
        'La operación intenta salir de una carpeta autorizada.',
      );
    }
  }

  static String unirSeguro(String raiz, String nombre) {
    exigirNombreValido(nombre);
    final ruta = p.join(raiz, nombre);
    exigirDentroDe(ruta, raiz);
    return ruta;
  }
}
