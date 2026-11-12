import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_archivos/datos/cache_miniaturas.dart';
import 'package:gestor_archivos/datos/repositorio_ubicaciones.dart';
import 'package:gestor_archivos/datos/servicio_archivos.dart';
import 'package:gestor_archivos/dominio/error_archivo.dart';
import 'package:gestor_archivos/dominio/modelos.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temporal;
  late RaizAutorizada raiz;
  late ServicioRutas servicio;

  setUp(() {
    temporal = Directory.systemTemp.createTempSync('p4-servicio-');
    raiz = RaizAutorizada(
      id: 'privado',
      nombre: 'Espacio de la app',
      origen: OrigenArchivo.privado,
      referencia: temporal.path,
    );
    servicio = ServicioRutas(origen: OrigenArchivo.privado);
  });

  tearDown(() {
    if (temporal.existsSync()) temporal.deleteSync(recursive: true);
  });

  Uint8List bytes(String texto) => Uint8List.fromList(utf8.encode(texto));

  test('crea, lista, lee, copia, mueve, renombra y elimina', () async {
    await servicio.crearCarpeta(raiz, temporal.path, 'Documentos');
    final carpeta = p.join(temporal.path, 'Documentos');
    await servicio.escribir(raiz, carpeta, 'notas.txt', bytes('hola IPN'));

    final lista = await servicio.listar(raiz, carpeta);
    expect(lista.map((e) => e.nombre), contains('notas.txt'));

    final entrada = lista.firstWhere((e) => e.nombre == 'notas.txt');
    expect(utf8.decode(await servicio.leer(entrada)), 'hola IPN');
    expect(entrada.tamano, 8);
    expect(entrada.mime, 'text/plain');

    await servicio.crearCarpeta(raiz, temporal.path, 'Destino');
    final destino = p.join(temporal.path, 'Destino');
    await servicio.copiar(entrada, raiz, destino);
    expect(File(p.join(destino, 'notas.txt')).existsSync(), isTrue);

    await servicio.crearCarpeta(raiz, temporal.path, 'Destino2');
    final destino2 = p.join(temporal.path, 'Destino2');
    await servicio.mover(entrada, raiz, destino2);
    expect(File(p.join(carpeta, 'notas.txt')).existsSync(), isFalse);
    final movida = (await servicio.listar(raiz, destino2)).firstWhere((e) => e.nombre == 'notas.txt');

    await servicio.renombrar(movida, destino2, 'renombrada.txt');
    expect(File(p.join(destino2, 'renombrada.txt')).existsSync(), isTrue);

    final renombrada = (await servicio.listar(raiz, destino2)).firstWhere((e) => e.nombre == 'renombrada.txt');
    await servicio.eliminar(renombrada);
    expect(File(p.join(destino2, 'renombrada.txt')).existsSync(), isFalse);
  });

  test('conflicto de nombre no sobrescribe sin permiso', () async {
    await servicio.escribir(raiz, temporal.path, 'a.txt', bytes('uno'));
    expect(
      () => servicio.escribir(raiz, temporal.path, 'a.txt', bytes('dos')),
      throwsA(isA<ErrorArchivo>().having((e) => e.tipo, 'tipo', TipoErrorArchivo.conflicto)),
    );
    await servicio.escribir(raiz, temporal.path, 'a.txt', bytes('dos'), sobrescribir: true);
    final entrada = (await servicio.listar(raiz, temporal.path)).single;
    expect(utf8.decode(await servicio.leer(entrada)), 'dos');
  });

  test('archivo inexistente y ruta fuera de la raíz se rechazan', () async {
    final fantasma = EntradaArchivo(
      nombre: 'no.txt',
      referencia: p.join(temporal.path, 'no.txt'),
      esCarpeta: false,
      origen: OrigenArchivo.privado,
      raiz: raiz,
    );
    expect(
      () => servicio.leer(fantasma),
      throwsA(isA<ErrorArchivo>().having((e) => e.tipo, 'tipo', TipoErrorArchivo.noEncontrado)),
    );
    final fuera = EntradaArchivo(
      nombre: 'fuera.txt',
      referencia: p.join(temporal.path, '..', 'fuera.txt'),
      esCarpeta: false,
      origen: OrigenArchivo.privado,
      raiz: raiz,
    );
    expect(
      () => servicio.leer(fuera),
      throwsA(isA<ErrorArchivo>()),
    );
  });

  test('nombre inválido no crea archivos', () async {
    expect(
      () => servicio.escribir(raiz, temporal.path, '../escape.txt', bytes('x')),
      throwsA(isA<ErrorArchivo>().having((e) => e.tipo, 'tipo', TipoErrorArchivo.nombreInvalido)),
    );
    expect(File(p.join(temporal.path, '..', 'escape.txt')).existsSync(), isFalse);
  });

  test('caché de miniaturas genera, reutiliza y limpia', () async {
    final cacheDir = Directory.systemTemp.createTempSync('p4-cache-');
    addTearDown(() => cacheDir.deleteSync(recursive: true));
    final imagen = img.Image(width: 20, height: 12);
    img.fill(imagen, color: img.ColorRgb8(108, 29, 69));
    final png = Uint8List.fromList(img.encodePng(imagen));
    final archivo = File(p.join(temporal.path, 'foto.png'));
    await archivo.writeAsBytes(png);
    final entrada = EntradaArchivo(
      nombre: 'foto.png',
      referencia: archivo.path,
      esCarpeta: false,
      origen: OrigenArchivo.privado,
      raiz: raiz,
      tamano: png.length,
      modificado: DateTime.now(),
    );
    final cache = CacheMiniaturas(cacheDir);
    var lecturas = 0;
    final primera = await cache.obtener(entrada, leer: () async {
      lecturas++;
      return png;
    });
    expect(primera, isNotNull);
    expect(lecturas, 1);
    final segunda = await cache.obtener(entrada, leer: () async {
      lecturas++;
      return png;
    });
    expect(segunda, isNotNull);
    expect(lecturas, 1, reason: 'la segunda vez debe salir de la caché');
    expect(await cache.tamanoBytes(), greaterThan(0));
    await cache.limpiar();
    expect(await cache.tamanoBytes(), 0);
  });

  test('favoritos y recientes persisten en shared_preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final repo = RepositorioUbicaciones(prefs);
    final entrada = EntradaArchivo(
      nombre: 'datos.json',
      referencia: p.join(temporal.path, 'datos.json'),
      esCarpeta: false,
      origen: OrigenArchivo.privado,
      raiz: raiz,
      mime: 'application/json',
    );
    await repo.guardarFavoritos(<EntradaArchivo>[entrada]);
    await repo.guardarRecientes(<EntradaArchivo>[entrada]);
    expect(repo.cargarFavoritos().single.nombre, 'datos.json');
    expect(repo.cargarRecientes().single.raiz.id, 'privado');
  });
}
