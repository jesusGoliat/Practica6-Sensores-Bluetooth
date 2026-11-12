import 'dart:convert';

import 'package:xml/xml.dart';

import '../dominio/carta.dart';
import '../dominio/checksum.dart';
import '../dominio/configuracion_partida.dart';
import '../dominio/error_partida.dart';
import '../dominio/estado_partida.dart';
import '../dominio/validador_partida.dart';

/// Contrato de los tres formatos de guardado.
abstract class CodificadorPartida {
  String get extension;
  String get etiqueta;

  String codificar(EstadoPartida partida);

  /// Decodifica y valida. Lanza [ErrorPartida] con un mensaje legible.
  EstadoPartida decodificar(String contenido);
}

Map<String, Object?> _conChecksum(EstadoPartida partida) {
  final mapa = partida.aJson();
  mapa['checksum'] = fnv1a(jsonEncode(partida.aJson()));
  return mapa;
}

EstadoPartida _validarConChecksum(EstadoPartida partida, String? checksumLeido) {
  ValidadorPartida.validar(partida);
  final esperado = fnv1a(jsonEncode(partida.aJson()));
  if (checksumLeido == null || checksumLeido.isEmpty) {
    throw const ErrorPartida(TipoErrorPartida.incompleta, 'La partida no incluye checksum.');
  }
  if (checksumLeido != esperado) {
    throw const ErrorPartida(
      TipoErrorPartida.checksum,
      'El archivo está dañado o fue modificado (checksum inválido).',
    );
  }
  return partida;
}

/// JSON legible con sangría y checksum.
class CodificadorJson implements CodificadorPartida {
  const CodificadorJson();

  @override
  String get extension => 'json';

  @override
  String get etiqueta => 'JSON';

  @override
  String codificar(EstadoPartida partida) {
    final mapa = _conChecksum(partida);
    return const JsonEncoder.withIndent('  ').convert(mapa);
  }

  @override
  EstadoPartida decodificar(String contenido) {
    if (contenido.trim().isEmpty) {
      throw const ErrorPartida(TipoErrorPartida.vacia, 'El archivo está vacío.');
    }
    dynamic decodificado;
    try {
      decodificado = jsonDecode(contenido);
    } on FormatException catch (e) {
      throw ErrorPartida(TipoErrorPartida.formato, 'JSON inválido: ${e.message}.');
    }
    if (decodificado is! Map) {
      throw const ErrorPartida(TipoErrorPartida.formato, 'El JSON no contiene un objeto de partida.');
    }
    final mapa = Map<String, Object?>.from(decodificado);
    if (mapa['schema'] != EstadoPartida.esquema) {
      throw const ErrorPartida(TipoErrorPartida.formato, 'El archivo no es una partida de Pares IPN.');
    }
    final checksumValor = mapa.remove('checksum');
    final checksum = checksumValor is String ? checksumValor : null;
    final partida = EstadoPartida.desdeJson(mapa);
    return _validarConChecksum(partida, checksum);
  }
}

/// XML con un elemento por campo y atributos para las cartas.
class CodificadorXml implements CodificadorPartida {
  const CodificadorXml();

  @override
  String get extension => 'xml';

  @override
  String get etiqueta => 'XML';

  @override
  String codificar(EstadoPartida partida) {
    final mapa = _conChecksum(partida);
    final b = XmlBuilder();
    b.element('partida', attributes: <String, String>{
      'schema': EstadoPartida.esquema,
      'version': '${partida.version}',
    }, nest: () {
      void campo(String nombre, Object? valor) => b.element(nombre, nest: () => b.text('$valor'));

      campo('id', mapa['id']);
      campo('semilla', mapa['semilla']);
      campo('nivel', mapa['nivel']);
      campo('modo', mapa['modo']);
      campo('filas', mapa['filas']);
      campo('columnas', mapa['columnas']);
      campo('puntaje', mapa['puntaje']);
      campo('tiempoSegundos', mapa['tiempoSegundos']);
      campo('terminada', mapa['terminada']);
      campo('perdida', mapa['perdida']);
      campo('racha', mapa['racha']);
      campo('mejorRacha', mapa['mejorRacha']);
      campo('etiqueta', mapa['etiqueta']);
      campo('creada', mapa['creada']);
      campo('actualizada', mapa['actualizada']);
      b.element('configuracion', attributes: <String, String>{
        'nombreJugador': partida.configuracion.nombreJugador,
        'sonido': '${partida.configuracion.sonido}',
        'animaciones': '${partida.configuracion.animaciones}',
        'formatoPreferido': partida.configuracion.formatoPreferido,
        'tema': partida.configuracion.tema,
      });
      b.element('tablero', nest: () {
        for (var i = 0; i < partida.tablero.length; i++) {
          final carta = partida.tablero[i];
          b.element('carta', attributes: <String, String>{
            'indice': '$i',
            'simbolo': carta.simboloId,
            'categoria': carta.categoria,
            'estado': carta.estado.name,
          });
        }
      });
      b.element('movimientos', nest: () {
        for (final m in partida.movimientos) {
          b.element('movimiento', attributes: <String, String>{
            'numero': '${m.numero}',
            'indiceA': '${m.indiceA}',
            'indiceB': '${m.indiceB}',
            'simboloA': m.simboloA,
            'simboloB': m.simboloB,
            'acierto': '${m.acierto}',
            'deltaPuntaje': '${m.deltaPuntaje}',
            'tiempoSegundos': '${m.tiempoSegundos}',
            'categoria': m.categoria,
          });
        }
      });
      campo('checksum', mapa['checksum']);
    });
    return b.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  @override
  EstadoPartida decodificar(String contenido) {
    if (contenido.trim().isEmpty) {
      throw const ErrorPartida(TipoErrorPartida.vacia, 'El archivo está vacío.');
    }
    XmlDocument documento;
    try {
      documento = XmlDocument.parse(contenido);
    } on XmlException catch (e) {
      throw ErrorPartida(
        TipoErrorPartida.incompleta,
        'XML incompleto o dañado: ${e.message}.',
      );
    }
    final raiz = documento.rootElement;
    if (raiz.name.local != 'partida') {
      throw const ErrorPartida(TipoErrorPartida.formato, 'El XML no contiene una partida.');
    }
    String? texto(String nombre) {
      for (final hijo in raiz.childElements) {
        if (hijo.name.local == nombre) return hijo.innerText.trim();
      }
      return null;
    }

    int entero(String nombre, [int porDefecto = 0]) =>
        int.tryParse(texto(nombre) ?? '') ?? porDefecto;
    bool booleano(String nombre, [bool porDefecto = false]) =>
        (texto(nombre) ?? '$porDefecto').toLowerCase() == 'true';

    final configuracion = <String, Object?>{
      'nombreJugador': 'Jugador IPN',
      'sonido': true,
      'animaciones': true,
      'formatoPreferido': 'xml',
      'tema': 'guinda',
    };
    for (final hijo in raiz.childElements) {
      if (hijo.name.local == 'configuracion') {
        configuracion['nombreJugador'] = hijo.getAttribute('nombreJugador') ?? 'Jugador IPN';
        configuracion['sonido'] = hijo.getAttribute('sonido') != 'false';
        configuracion['animaciones'] = hijo.getAttribute('animaciones') != 'false';
        configuracion['formatoPreferido'] = hijo.getAttribute('formatoPreferido') ?? 'xml';
        configuracion['tema'] = hijo.getAttribute('tema') ?? 'guinda';
      }
    }

    final tablero = <Map<String, Object?>>[];
    final movimientos = <Map<String, Object?>>[];
    for (final hijo in raiz.childElements) {
      if (hijo.name.local == 'tablero') {
        for (final carta in hijo.childElements.where((e) => e.name.local == 'carta')) {
          tablero.add(<String, Object?>{
            'simbolo': carta.getAttribute('simbolo') ?? '',
            'categoria': carta.getAttribute('categoria') ?? '',
            'estado': carta.getAttribute('estado') ?? 'oculta',
          });
        }
      } else if (hijo.name.local == 'movimientos') {
        for (final m in hijo.childElements.where((e) => e.name.local == 'movimiento')) {
          movimientos.add(<String, Object?>{
            'numero': int.tryParse(m.getAttribute('numero') ?? '') ?? 0,
            'indiceA': int.tryParse(m.getAttribute('indiceA') ?? '') ?? 0,
            'indiceB': int.tryParse(m.getAttribute('indiceB') ?? '') ?? 0,
            'simboloA': m.getAttribute('simboloA') ?? '',
            'simboloB': m.getAttribute('simboloB') ?? '',
            'acierto': (m.getAttribute('acierto') ?? 'false') == 'true',
            'deltaPuntaje': int.tryParse(m.getAttribute('deltaPuntaje') ?? '') ?? 0,
            'tiempoSegundos': int.tryParse(m.getAttribute('tiempoSegundos') ?? '') ?? 0,
            'categoria': m.getAttribute('categoria') ?? '',
          });
        }
      }
    }

    final mapa = <String, Object?>{
      'schema': raiz.getAttribute('schema') ?? '',
      'version': int.tryParse(raiz.getAttribute('version') ?? '') ?? 1,
      'id': texto('id') ?? '',
      'semilla': entero('semilla'),
      'nivel': texto('nivel') ?? 'campus',
      'modo': texto('modo') ?? 'relajado',
      'filas': entero('filas', 4),
      'columnas': entero('columnas', 4),
      'puntaje': entero('puntaje'),
      'tiempoSegundos': entero('tiempoSegundos'),
      'terminada': booleano('terminada'),
      'perdida': booleano('perdida'),
      'racha': entero('racha'),
      'mejorRacha': entero('mejorRacha'),
      'etiqueta': texto('etiqueta') ?? '',
      'creada': texto('creada') ?? DateTime.now().toIso8601String(),
      'actualizada': texto('actualizada') ?? DateTime.now().toIso8601String(),
      'configuracion': configuracion,
      'tablero': tablero,
      'movimientos': movimientos,
    };
    if (mapa['schema'] != EstadoPartida.esquema) {
      throw const ErrorPartida(TipoErrorPartida.formato, 'El XML no es una partida de Pares IPN.');
    }
    final partida = EstadoPartida.desdeJson(mapa);
    return _validarConChecksum(partida, texto('checksum'));
  }
}

/// TXT por secciones clave=valor. Es el formato más fácil de inspeccionar a
/// mano y también incluye checksum.
class CodificadorTxt implements CodificadorPartida {
  const CodificadorTxt();

  @override
  String get extension => 'txt';

  @override
  String get etiqueta => 'Texto plano';

  @override
  String codificar(EstadoPartida partida) {
    final mapa = _conChecksum(partida);
    final lineas = <String>[
      'MEMORAMA-IPN',
      'version=${partida.version}',
      'id=${partida.id}',
      'semilla=${partida.semilla}',
      'nivel=${partida.nivel}',
      'modo=${partida.modo}',
      'filas=${partida.filas}',
      'columnas=${partida.columnas}',
      'puntaje=${partida.puntaje}',
      'tiempoSegundos=${partida.tiempoSegundos}',
      'terminada=${partida.terminada}',
      'perdida=${partida.perdida}',
      'racha=${partida.racha}',
      'mejorRacha=${partida.mejorRacha}',
      'etiqueta=${Uri.encodeComponent(partida.etiqueta)}',
      'creada=${partida.creada.toIso8601String()}',
      'actualizada=${partida.actualizada.toIso8601String()}',
      'configuracion=${Uri.encodeComponent(partida.configuracion.nombreJugador)}|'
          '${partida.configuracion.sonido}|${partida.configuracion.animaciones}|'
          '${partida.configuracion.formatoPreferido}|${partida.configuracion.tema}',
      'tablero=${partida.tablero.map((c) => '${c.simboloId}|${c.categoria}|${c.estado.name}').join(';')}',
      'movimientos=${partida.movimientos.map((m) => m.aLinea()).join(';')}',
      'checksum=${mapa['checksum']}',
      'FIN',
    ];
    return lineas.join('\n');
  }

  @override
  EstadoPartida decodificar(String contenido) {
    if (contenido.trim().isEmpty) {
      throw const ErrorPartida(TipoErrorPartida.vacia, 'El archivo está vacío.');
    }
    final lineas = contenido
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lineas.length < 2 || lineas.first.trim() != 'MEMORAMA-IPN') {
      throw const ErrorPartida(TipoErrorPartida.formato, 'El archivo no es una partida de Pares IPN.');
    }
    if (lineas.last.trim() != 'FIN') {
      throw const ErrorPartida(
        TipoErrorPartida.incompleta,
        'El archivo está incompleto: falta la línea FIN.',
      );
    }
    final campos = <String, String>{};
    for (final linea in lineas.sublist(1, lineas.length - 1)) {
      final pos = linea.indexOf('=');
      if (pos <= 0) {
        throw ErrorPartida(TipoErrorPartida.formato, 'Línea inválida en el TXT: $linea');
      }
      campos[linea.substring(0, pos).trim()] = linea.substring(pos + 1).trim();
    }
    String requerido(String clave) {
      final valor = campos[clave];
      if (valor == null) {
        throw ErrorPartida(TipoErrorPartida.incompleta, 'Falta el campo «$clave».');
      }
      return valor;
    }

    int entero(String clave, [int porDefecto = 0]) => int.tryParse(campos[clave] ?? '') ?? porDefecto;
    bool booleano(String clave) => (campos[clave] ?? 'false').toLowerCase() == 'true';

    final configPartes = (campos['configuracion'] ?? '').split('|');
    final configuracion = <String, Object?>{
      'nombreJugador': configPartes.isNotEmpty ? _decodificar(configPartes[0]) : 'Jugador IPN',
      'sonido': configPartes.length > 1 ? configPartes[1] == 'true' : true,
      'animaciones': configPartes.length > 2 ? configPartes[2] == 'true' : true,
      'formatoPreferido': configPartes.length > 3 ? configPartes[3] : 'txt',
      'tema': configPartes.length > 4 ? configPartes[4] : 'guinda',
    };
    final tablero = <Map<String, Object?>>[];
    final crudoTablero = requerido('tablero');
    if (crudoTablero.isNotEmpty) {
      for (final parte in crudoTablero.split(';')) {
        final p = parte.split('|');
        if (p.length < 3) {
          throw const ErrorPartida(TipoErrorPartida.formato, 'El tablero del TXT está incompleto.');
        }
        tablero.add(<String, Object?>{
          'simbolo': _decodificar(p[0]),
          'categoria': _decodificar(p[1]),
          'estado': p[2],
        });
      }
    }
    final movimientos = <Map<String, Object?>>[];
    final crudoMov = campos['movimientos'] ?? '';
    if (crudoMov.isNotEmpty) {
      for (final parte in crudoMov.split(';')) {
        final m = Movimiento.desdeLinea(parte);
        movimientos.add(m.aJson());
      }
    }

    final mapa = <String, Object?>{
      'schema': EstadoPartida.esquema,
      'version': entero('version', 1),
      'id': requerido('id'),
      'semilla': entero('semilla'),
      'nivel': requerido('nivel'),
      'modo': requerido('modo'),
      'filas': entero('filas', 4),
      'columnas': entero('columnas', 4),
      'puntaje': entero('puntaje'),
      'tiempoSegundos': entero('tiempoSegundos'),
      'terminada': booleano('terminada'),
      'perdida': booleano('perdida'),
      'racha': entero('racha'),
      'mejorRacha': entero('mejorRacha'),
      'etiqueta': _decodificar(campos['etiqueta'] ?? ''),
      'creada': campos['creada'] ?? DateTime.now().toIso8601String(),
      'actualizada': campos['actualizada'] ?? DateTime.now().toIso8601String(),
      'configuracion': configuracion,
      'tablero': tablero,
      'movimientos': movimientos,
    };
    final partida = EstadoPartida.desdeJson(mapa);
    return _validarConChecksum(partida, campos['checksum']);
  }

  String _decodificar(String valor) {
    try {
      return Uri.decodeComponent(valor);
    } on ArgumentError {
      return valor;
    }
  }
}

CodificadorPartida codificadorPorExtension(String extension) {
  switch (extension.toLowerCase()) {
    case 'json':
      return const CodificadorJson();
    case 'xml':
      return const CodificadorXml();
    case 'txt':
      return const CodificadorTxt();
    default:
      throw ErrorPartida(TipoErrorPartida.formato, 'Extensión no soportada: $extension.');
  }
}

/// Detecta el formato por extensión y, si no coincide, por el contenido.
CodificadorPartida? detectarCodificador(String nombre, String contenido) {
  final punto = nombre.lastIndexOf('.');
  if (punto >= 0) {
    final ext = nombre.substring(punto + 1).toLowerCase();
    if (ext == 'json' || ext == 'xml' || ext == 'txt') {
      return codificadorPorExtension(ext);
    }
  }
  final limpio = contenido.trimLeft();
  if (limpio.startsWith('{')) return const CodificadorJson();
  if (limpio.startsWith('<')) return const CodificadorXml();
  if (limpio.startsWith('MEMORAMA-IPN')) return const CodificadorTxt();
  return null;
}

/// Reconstruye una partida desde un mapa ya parseado (usado por pruebas).
EstadoPartida desdeMapa(Map<String, Object?> mapa) => EstadoPartida.desdeJson(mapa);

/// Configuración por defecto para pruebas o partidas antiguas.
ConfiguracionPartida configuracionPorDefecto() => const ConfiguracionPartida();
