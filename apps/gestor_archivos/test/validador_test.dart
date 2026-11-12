import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_archivos/dominio/error_archivo.dart';
import 'package:gestor_archivos/dominio/validador_rutas.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ValidadorRutas', () {
    test('acepta nombres normales', () {
      expect(ValidadorRutas.nombreValido('notas.md'), isTrue);
      expect(ValidadorRutas.nombreValido('datos 2026.json'), isTrue);
      expect(ValidadorRutas.nombreValido('carpeta-ipn'), isTrue);
    });

    test('rechaza traversal, separadores y nombres vacíos', () {
      for (final nombre in <String>['', '..', '.', 'a/b', r'a\b', 'a:b', 'a*b', '   ']) {
        expect(ValidadorRutas.nombreValido(nombre), isFalse, reason: nombre);
      }
    });

    test('detecta rutas fuera de la raíz', () {
      final raiz = Directory.systemTemp.createTempSync('p4-val-');
      addTearDown(() => raiz.deleteSync(recursive: true));
      expect(ValidadorRutas.dentroDe(p.join(raiz.path, 'a.txt'), raiz.path), isTrue);
      expect(ValidadorRutas.dentroDe(p.join(raiz.path, '..', 'fuera.txt'), raiz.path), isFalse);
      expect(ValidadorRutas.dentroDe('/otra/ruta', raiz.path), isFalse);
    });

    test('exigirNombreValido lanza ErrorArchivo', () {
      expect(
        () => ValidadorRutas.exigirNombreValido('../x'),
        throwsA(isA<ErrorArchivo>().having((e) => e.tipo, 'tipo', TipoErrorArchivo.nombreInvalido)),
      );
    });
  });
}
