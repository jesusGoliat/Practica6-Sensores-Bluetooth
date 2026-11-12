import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formato', () {
    test('tamaños legibles', () {
      expect(Formato.bytes(512), '512 B');
      expect(Formato.bytes(2048), '2.0 KB');
      expect(Formato.bytes(null), 'No disponible');
    });

    test('duración mm:ss', () {
      expect(Formato.duracion(5), '00:05');
      expect(Formato.duracion(125), '02:05');
    });
  });

  group('MapaTipos', () {
    test('reconoce JSON, XML, Markdown e imágenes', () {
      expect(MapaTipos.tipoDe('datos.json').esJson, isTrue);
      expect(MapaTipos.tipoDe('configuracion.xml').esXml, isTrue);
      expect(MapaTipos.tipoDe('notas.md').esMarkdown, isTrue);
      expect(MapaTipos.tipoDe('foto.PNG').esImagen, isTrue);
    });

    test('un formato desconocido no inventa UTType', () {
      final tipo = MapaTipos.tipoDe('muestra.xyz');
      expect(tipo.conocido, isFalse);
      expect(tipo.utType, isEmpty);
      expect(tipo.tieneVisor, isFalse);
    });

    test('MIME y UTType de JSON', () {
      final tipo = MapaTipos.tipoDe('datos.json');
      expect(tipo.mime, 'application/json');
      expect(tipo.utType, 'public.json');
    });
  });

  group('Resaltador', () {
    test('embellece JSON válido', () {
      final resultado = Resaltador.preparar('datos.json', '{"a":1,"b":[true,null]}');
      expect(resultado.error, isNull);
      expect(resultado.texto, contains('\n  "a": 1'));
      expect(resultado.tipo, TipoResaltado.json);
    });

    test('JSON inválido conserva el texto y reporta error', () {
      const crudo = '{"a": 1,}';
      final resultado = Resaltador.preparar('datos.json', crudo);
      expect(resultado.error, isNotNull);
      expect(resultado.texto, crudo);
    });

    test('embellece XML válido', () {
      final resultado = Resaltador.preparar('config.xml', '<a><b>1</b></a>');
      expect(resultado.error, isNull);
      expect(resultado.texto, contains('<b>1</b>'));
      expect(resultado.tipo, TipoResaltado.xml);
    });

    test('XML inválido conserva el texto y reporta error', () {
      final resultado = Resaltador.preparar('config.xml', '<a><b></a>');
      expect(resultado.error, isNotNull);
    });
  });

  test('los dos temas generan esquemas claro y oscuro', () {
    for (final visual in TemaVisual.values) {
      for (final brillo in Brightness.values) {
        final tema = construirTema(visual: visual, brillo: brillo);
        expect(tema.colorScheme.brightness, brillo);
        expect(tema.useMaterial3, isTrue);
      }
    }
  });
}
