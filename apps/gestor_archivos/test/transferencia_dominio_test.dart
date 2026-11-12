import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_archivos/dominio/transferencia/cola_transferencias.dart';
import 'package:gestor_archivos/dominio/transferencia/estado_transferencia.dart';
import 'package:gestor_archivos/dominio/transferencia/historial_transferencias.dart';
import 'package:gestor_archivos/dominio/transferencia/metadatos_archivo.dart';
import 'package:gestor_archivos/dominio/transferencia/registro_transferencia.dart';
import 'package:gestor_archivos/dominio/transferencia/validador_transferencia.dart';

final _sha = 'a' * 64;

MetadatosArchivo meta({
  String nombre = 'nota.txt',
  String tipo = 'txt',
  int longitud = 100,
  String? sha,
  int bloque = 2048,
}) =>
    MetadatosArchivo(
        id: 'a1b2c3d4', nombre: nombre, tipo: tipo, longitud: longitud, sha256: sha ?? _sha, bloque: bloque);

RegistroTransferencia reg([EstadoTransferencia e = EstadoTransferencia.pendiente]) {
  var r = RegistroTransferencia.nuevo(
      id: 'x${e.name}',
      direccion: DireccionTransferencia.enviado,
      nombre: 'a.txt',
      tipo: 'txt',
      longitud: 10);
  if (e == EstadoTransferencia.pendiente) return r;
  r = r.conEstado(EstadoTransferencia.enCurso);
  if (e == EstadoTransferencia.enCurso) return r;
  return r.conEstado(e, verificado: true);
}

void main() {
  group('ValidadorTransferencia', () {
    test('acepta txt json xml jpg y jpeg como jpg', () {
      for (final n in ['a.txt', 'b.json', 'c.xml', 'd.jpg', 'e.JPEG']) {
        final tipo = ValidadorTransferencia.tipoDeNombre(n)!;
        expect(ValidadorTransferencia.validarOferta(meta(nombre: n, tipo: tipo)), isNull, reason: n);
      }
      expect(ValidadorTransferencia.tipoDeNombre('x.jpeg'), 'jpg');
    });

    test('rechaza tipos y extensiones no permitidas', () {
      expect(ValidadorTransferencia.tipoDeNombre('x.exe'), isNull);
      expect(ValidadorTransferencia.validarOferta(meta(nombre: 'x.exe', tipo: 'exe'))!.codigo, 'tipo');
      expect(ValidadorTransferencia.validarOferta(meta(nombre: 'sin_extension', tipo: 'txt'))!.codigo, 'tipo');
    });

    test('la extensión debe coincidir con el tipo', () {
      final e = ValidadorTransferencia.validarOferta(meta(nombre: 'a.json', tipo: 'txt'));
      expect(e!.codigo, 'tipo');
    });

    test('rechaza separadores, .. y caracteres raros', () {
      for (final n in ['../x.txt', 'a/b.txt', r'a\b.txt', 'a..b.txt', 'a*b.txt', 'a:b.txt', '']) {
        expect(ValidadorTransferencia.validarOferta(meta(nombre: n))!.codigo, anyOf('nombre', 'tipo'),
            reason: n);
      }
    });

    test('máximo 80 caracteres', () {
      final ok = '${'a' * 76}.txt';
      final largo = '${'a' * 77}.txt';
      expect(ValidadorTransferencia.validarOferta(meta(nombre: ok)), isNull);
      expect(ValidadorTransferencia.validarOferta(meta(nombre: largo))!.codigo, 'nombre');
    });

    test('acepta acentos, ñ, espacios y guiones', () {
      expect(ValidadorTransferencia.validarOferta(meta(nombre: 'Mi año - útil_1.txt')), isNull);
    });

    test('tamaño: 512 KiB sí, 512 KiB + 1 no, vacío no', () {
      expect(ValidadorTransferencia.validarOferta(meta(longitud: 512 * 1024)), isNull);
      expect(ValidadorTransferencia.validarOferta(meta(longitud: 512 * 1024 + 1))!.codigo, 'tamano');
      expect(ValidadorTransferencia.validarOferta(meta(longitud: 0))!.codigo, 'tamano');
    });

    test('bloque y sha256 mal formados', () {
      expect(ValidadorTransferencia.validarOferta(meta(bloque: 1024))!.codigo, 'formato');
      expect(ValidadorTransferencia.validarOferta(meta(sha: 'zz'))!.codigo, 'formato');
    });

    test('sanear reemplaza caracteres no permitidos y recorta', () {
      expect(ValidadorTransferencia.sanear('a:b*c.txt'), 'a_b_c.txt');
      expect(ValidadorTransferencia.sanear('../../x.txt'), 'x.txt');
      expect(ValidadorTransferencia.sanear('a..b.txt'), 'a.b.txt');
      final s = ValidadorTransferencia.sanear('${'n' * 200}.json');
      expect(s.length, 80);
      expect(s.endsWith('.json'), isTrue);
      expect(ValidadorTransferencia.validarNombre(s, 'json'), isNull);
    });

    test('motivoNoEnviable deshabilita con razón', () {
      expect(ValidadorTransferencia.motivoNoEnviable('a.txt', 10), isNull);
      expect(ValidadorTransferencia.motivoNoEnviable('a.pdf', 10), isNotNull);
      expect(ValidadorTransferencia.motivoNoEnviable('a.txt', 600 * 1024), contains('512 KiB'));
    });

    test('nombre único con (2), (3)', () {
      final usados = {'nota.txt', 'nota (2).txt'};
      expect(ValidadorTransferencia.nombreUnico('otra.txt', usados.contains), 'otra.txt');
      expect(ValidadorTransferencia.nombreUnico('nota.txt', usados.contains), 'nota (3).txt');
    });
  });

  group('ColaTransferencias', () {
    test('acepta 5 y rechaza el sexto con mensaje', () {
      final c = ColaTransferencias<int>();
      for (var i = 0; i < 5; i++) {
        expect(c.encolar(i), isNull);
      }
      expect(c.encolar(6), ColaTransferencias.mensajeLlena);
      expect(c.longitud, 5);
      expect(c.siguiente(), 0);
      expect(c.encolar(7), isNull);
    });
  });

  group('transiciones', () {
    test('legales', () {
      expect(reg().conEstado(EstadoTransferencia.enCurso).estado, EstadoTransferencia.enCurso);
      expect(reg().conEstado(EstadoTransferencia.cancelado).estado, EstadoTransferencia.cancelado);
      expect(reg(EstadoTransferencia.enCurso).conEstado(EstadoTransferencia.fallido, motivo: 'x').motivo, 'x');
    });

    test('ilegales', () {
      expect(() => reg().conEstado(EstadoTransferencia.completado, verificado: true),
          throwsA(isA<TransicionInvalida>()));
      for (final f in [
        EstadoTransferencia.completado,
        EstadoTransferencia.cancelado,
        EstadoTransferencia.fallido
      ]) {
        expect(() => reg(f).conEstado(EstadoTransferencia.enCurso), throwsA(isA<TransicionInvalida>()));
      }
    });

    test('completado exige verificación', () {
      expect(() => reg(EstadoTransferencia.enCurso).conEstado(EstadoTransferencia.completado),
          throwsA(isA<TransicionInvalida>()));
      final r = reg(EstadoTransferencia.enCurso).conEstado(EstadoTransferencia.completado, verificado: true);
      expect(r.progreso, 1);
      expect(r.fin, isNotNull);
    });
  });

  group('HistorialTransferencias', () {
    test('JSON ida y vuelta', () {
      final h = HistorialTransferencias()..guardar(reg(EstadoTransferencia.completado));
      final h2 = HistorialTransferencias.desdeTexto(h.toJsonTexto());
      expect(h2.registros.single.estado, EstadoTransferencia.completado);
      expect(h2.registros.single.nombre, 'a.txt');
    });

    test('regla de reinicio: pendiente y enCurso -> fallido', () {
      final h = HistorialTransferencias()
        ..guardar(reg())
        ..guardar(reg(EstadoTransferencia.enCurso))
        ..guardar(reg(EstadoTransferencia.completado))
        ..guardar(reg(EstadoTransferencia.cancelado));
      final h2 = HistorialTransferencias.desdeTexto(h.toJsonTexto(), reinicio: true);
      final porNombre = {for (final r in h2.registros) r.id: r};
      expect(porNombre['xpendiente']!.estado, EstadoTransferencia.fallido);
      expect(porNombre['xenCurso']!.estado, EstadoTransferencia.fallido);
      expect(porNombre['xenCurso']!.motivo, 'interrumpida por reinicio');
      expect(porNombre['xcompletado']!.estado, EstadoTransferencia.completado);
      expect(porNombre['xcancelado']!.estado, EstadoTransferencia.cancelado);
    });

    test('JSON corrupto no rompe', () {
      expect(HistorialTransferencias.desdeTexto('{{{ no json').registros, isEmpty);
    });
  });
}
