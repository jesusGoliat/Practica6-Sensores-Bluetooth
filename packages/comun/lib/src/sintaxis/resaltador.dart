import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../tipos/mapa_tipos.dart';

/// Tipo de resaltado que se aplicará al contenido.
enum TipoResaltado { json, xml, markdown, texto }

/// Resultado de intentar embellecer un archivo. Si `error` no es null se
/// muestra el texto original y un aviso legible, sin bloquear la app.
class ContenidoResaltado {
  const ContenidoResaltado(this.texto, this.tipo, {this.error});
  final String texto;
  final TipoResaltado tipo;
  final String? error;
}

/// Resaltador de sintaxis propio (sin dependencias de renderizado web).
///
/// Se eligió un tokenizador sencillo sobre `TextSpan` porque las vistas deben
/// funcionar offline y en Android e iOS con el mismo resultado.
abstract final class Resaltador {
  static ContenidoResaltado preparar(String nombre, String crudo) {
    final info = MapaTipos.tipoDe(nombre);
    if (info.esJson) {
      try {
        final objeto = jsonDecode(crudo);
        final bonito = const JsonEncoder.withIndent('  ').convert(objeto);
        return ContenidoResaltado(bonito, TipoResaltado.json);
      } on FormatException catch (e) {
        return ContenidoResaltado(
          crudo,
          TipoResaltado.json,
          error: 'JSON inválido: ${e.message}. Se muestra el texto original.',
        );
      }
    }
    if (info.esXml) {
      try {
        final documento = XmlDocument.parse(crudo);
        final bonito = documento.toXmlString(pretty: true, indent: '  ');
        return ContenidoResaltado(bonito, TipoResaltado.xml);
      } on XmlException catch (e) {
        return ContenidoResaltado(
          crudo,
          TipoResaltado.xml,
          error: 'XML inválido: ${e.message}. Se muestra el texto original.',
        );
      }
    }
    if (info.esMarkdown) {
      return ContenidoResaltado(crudo, TipoResaltado.markdown);
    }
    return ContenidoResaltado(crudo, TipoResaltado.texto);
  }

  static List<TextSpan> spans({
    required String texto,
    required TipoResaltado tipo,
    required ColorScheme esquema,
  }) {
    switch (tipo) {
      case TipoResaltado.json:
        return _json(texto, esquema);
      case TipoResaltado.xml:
        return _xml(texto, esquema);
      case TipoResaltado.markdown:
        return _markdown(texto, esquema);
      case TipoResaltado.texto:
        return <TextSpan>[TextSpan(text: texto, style: TextStyle(color: esquema.onSurface))];
    }
  }

  static List<TextSpan> _json(String texto, ColorScheme esquema) {
    // Clave: "..." seguida de dos puntos. Valor: cadena, número, booleano/null.
    final patron = RegExp(
      r'("(?:\\.|[^"\\])*")(\s*:)|("(?:\\.|[^"\\])*")|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|\b(true|false|null)\b|([{}\[\],:])',
    );
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in patron.allMatches(texto)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: texto.substring(cursor, m.start), style: TextStyle(color: esquema.onSurfaceVariant)));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: TextStyle(color: esquema.primary, fontWeight: FontWeight.w600),
        ));
        spans.add(TextSpan(text: m.group(2), style: TextStyle(color: esquema.onSurfaceVariant)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: m.group(3), style: TextStyle(color: esquema.tertiary)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(text: m.group(4), style: TextStyle(color: esquema.secondary)));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(text: m.group(5), style: TextStyle(color: esquema.error)));
      } else {
        spans.add(TextSpan(text: m.group(0), style: TextStyle(color: esquema.onSurfaceVariant)));
      }
      cursor = m.end;
    }
    if (cursor < texto.length) {
      spans.add(TextSpan(text: texto.substring(cursor), style: TextStyle(color: esquema.onSurface)));
    }
    return spans;
  }

  static List<TextSpan> _xml(String texto, ColorScheme esquema) {
    final spans = <TextSpan>[];
    var cursor = 0;
    final patron = RegExp(r'<!--[\s\S]*?-->|<\?[\s\S]*?\?>|<[^>]*>');
    for (final m in patron.allMatches(texto)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: texto.substring(cursor, m.start), style: TextStyle(color: esquema.onSurface)));
      }
      final token = m.group(0)!;
      if (token.startsWith('<!--')) {
        spans.add(TextSpan(text: token, style: TextStyle(color: esquema.outline, fontStyle: FontStyle.italic)));
      } else {
        // Etiquetas: nombre en color primario, atributos y valores diferenciados.
        final interior = token.substring(1, token.length - 1);
        final esCierre = interior.startsWith('/');
        final cuerpo = esCierre ? interior.substring(1) : interior;
        final nombreMatch = RegExp(r'^[A-Za-z_][\w:.-]*').firstMatch(cuerpo);
        final nombre = nombreMatch?.group(0) ?? '';
        final resto = cuerpo.substring(nombre.length);
        spans.add(TextSpan(text: '<${esCierre ? '/' : ''}', style: TextStyle(color: esquema.onSurfaceVariant)));
        spans.add(TextSpan(
          text: nombre,
          style: TextStyle(color: esquema.primary, fontWeight: FontWeight.w600),
        ));
        final atributos = RegExp(r'([\w:.-]+)(\s*=\s*)("[^"]*")?');
        var usado = 0;
        for (final a in atributos.allMatches(resto)) {
          if (a.start > usado) {
            spans.add(TextSpan(text: resto.substring(usado, a.start), style: TextStyle(color: esquema.onSurfaceVariant)));
          }
          spans.add(TextSpan(text: a.group(1), style: TextStyle(color: esquema.secondary)));
          if (a.group(2) != null) {
            spans.add(TextSpan(text: a.group(2), style: TextStyle(color: esquema.onSurfaceVariant)));
          }
          if (a.group(3) != null) {
            spans.add(TextSpan(text: a.group(3), style: TextStyle(color: esquema.tertiary)));
          }
          usado = a.end;
        }
        if (usado < resto.length) {
          spans.add(TextSpan(text: resto.substring(usado), style: TextStyle(color: esquema.onSurfaceVariant)));
        }
        spans.add(TextSpan(text: '>', style: TextStyle(color: esquema.onSurfaceVariant)));
      }
      cursor = m.end;
    }
    if (cursor < texto.length) {
      spans.add(TextSpan(text: texto.substring(cursor), style: TextStyle(color: esquema.onSurface)));
    }
    return spans;
  }

  static List<TextSpan> _markdown(String texto, ColorScheme esquema) {
    final spans = <TextSpan>[];
    final lineas = texto.split('\n');
    for (var i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      var estilo = TextStyle(color: esquema.onSurface);
      if (linea.startsWith('#')) {
        estilo = TextStyle(color: esquema.primary, fontWeight: FontWeight.bold);
      } else if (linea.startsWith('>')) {
        estilo = TextStyle(color: esquema.tertiary, fontStyle: FontStyle.italic);
      } else if (linea.trimLeft().startsWith('- ') || linea.trimLeft().startsWith('* ')) {
        estilo = TextStyle(color: esquema.secondary);
      } else if (linea.startsWith('```')) {
        estilo = TextStyle(color: esquema.outline, fontFamily: 'monospace');
      }
      spans.add(TextSpan(text: linea, style: estilo));
      if (i < lineas.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }
}
