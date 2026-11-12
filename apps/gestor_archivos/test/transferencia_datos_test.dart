import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_archivos/datos/transferencia/emisor_archivo.dart';
import 'package:gestor_archivos/datos/transferencia/receptor_archivo.dart';
import 'package:gestor_archivos/datos/transferencia/repositorio_historial.dart';
import 'package:gestor_archivos/dominio/transferencia/estado_transferencia.dart';
import 'package:gestor_archivos/dominio/transferencia/historial_transferencias.dart';
import 'package:gestor_archivos/dominio/transferencia/registro_transferencia.dart';
import 'package:path/path.dart' as p;

class Escenario {
  Escenario({bool acepta = true, bool alterarBloque = false, bool alterarNombre = false}) {
    raiz = Directory.systemTemp.createTempSync('p6-transf-');
    recibidos = Directory(p.join(raiz.path, 'recibidos'));
    tmp = Directory(p.join(raiz.path, 'tmp'));
    final (a, b) = TransporteMemoria.par(maxFragmento: 185);
    ta = a;
    final enlaceTx = Enlace(a, tiempoAck: const Duration(seconds: 2));
    final enlaceRx = Enlace(b, tiempoAck: const Duration(seconds: 2));
    receptor = ReceptorArchivo(
      enlace: enlaceRx,
      directorioRecibidos: recibidos,
      directorioTmp: tmp,
      decidir: (m, e) async => acepta,
      alCambiar: rx.add,
    );
    emisor = EmisorArchivo(
      enlace: enlaceTx,
      alterarBloque: alterarBloque,
      alterarNombre: alterarNombre,
      tiempoRespuesta: const Duration(seconds: 5),
      tiempoBloque: const Duration(seconds: 5),
      alCambiar: (r) {
        tx.add(r);
        alProgreso?.call(r);
      },
    );
  }

  late Directory raiz, recibidos, tmp;
  late TransporteMemoria ta;
  late ReceptorArchivo receptor;
  late EmisorArchivo emisor;
  final List<RegistroTransferencia> rx = [], tx = [];
  void Function(RegistroTransferencia)? alProgreso;

  Future<RegistroTransferencia> enviar(String nombre, Uint8List bytes) =>
      emisor.enviar(id: 'a1b2c3d4', nombre: nombre, leer: () async => bytes, dispositivo: 'Rx');

  RegistroTransferencia get ultimoRx => rx.last;

  Future<void> esperarRxFinal() async {
    for (var i = 0; i < 200; i++) {
      if (rx.isNotEmpty && rx.last.estado.esFinal) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  List<String> get archivosRecibidos =>
      recibidos.existsSync() ? recibidos.listSync().map((e) => p.basename(e.path)).toList() : [];
  List<String> get archivosTmp =>
      tmp.existsSync() ? tmp.listSync().map((e) => p.basename(e.path)).toList() : [];

  void cerrar() => raiz.deleteSync(recursive: true);
}

Uint8List datos(int n) => Uint8List.fromList(List.generate(n, (i) => (i * 7 + 3) % 256));

void main() {
  group('transferencia completa por TransporteMemoria', () {
    final casos = <String, Uint8List>{
      'nota.txt': Uint8List.fromList('Hola IPN, ñandú'.codeUnits),
      'datos.json': Uint8List.fromList('{"a":1,"b":[1,2,3]}'.codeUnits),
      'config.xml': Uint8List.fromList('<a><b>1</b></a>'.codeUnits),
      'foto.jpg': Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...datos(900), 0xFF, 0xD9]),
    };
    for (final e in casos.entries) {
      test('envía ${e.key}', () async {
        final s = Escenario();
        addTearDown(s.cerrar);
        final r = await s.enviar(e.key, e.value);
        await s.esperarRxFinal();
        expect(r.estado, EstadoTransferencia.completado, reason: r.motivo);
        expect(s.ultimoRx.estado, EstadoTransferencia.completado);
        expect(s.archivosRecibidos, [e.key]);
        expect(File(p.join(s.recibidos.path, e.key)).readAsBytesSync(), e.value);
        expect(s.archivosTmp, isEmpty);
      });
    }

    test('archivo de 300 KB en múltiples bloques con progreso creciente', () async {
      final s = Escenario();
      addTearDown(s.cerrar);
      final bytes = datos(300 * 1000);
      final progresos = <double>[];
      s.alProgreso = (r) => progresos.add(r.progreso);
      final r = await s.enviar('grande.txt', bytes);
      await s.esperarRxFinal();
      expect(r.estado, EstadoTransferencia.completado, reason: r.motivo);
      expect(progresos.where((x) => x > 0 && x < 1).length, greaterThan(100));
      for (var i = 1; i < progresos.length; i++) {
        expect(progresos[i], greaterThanOrEqualTo(progresos[i - 1]));
      }
      final guardado = File(p.join(s.recibidos.path, 'grande.txt')).readAsBytesSync();
      expect(sha256.convert(guardado), sha256.convert(bytes));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('nombre existente recibe sufijo (2)', () async {
      final s = Escenario();
      addTearDown(s.cerrar);
      s.recibidos.createSync(recursive: true);
      File(p.join(s.recibidos.path, 'nota.txt')).writeAsStringSync('previo');
      final r = await s.enviar('nota.txt', datos(10));
      await s.esperarRxFinal();
      expect(r.estado, EstadoTransferencia.completado);
      expect(s.ultimoRx.nombre, 'nota (2).txt');
      expect(File(p.join(s.recibidos.path, 'nota.txt')).readAsStringSync(), 'previo');
    });
  });

  test('integridad: bloque alterado -> fallido en ambos y sin archivo final', () async {
    final s = Escenario(alterarBloque: true);
    addTearDown(s.cerrar);
    final r = await s.enviar('nota.txt', datos(5000));
    await s.esperarRxFinal();
    expect(r.estado, EstadoTransferencia.fallido);
    expect(r.motivo, contains('SHA-256'));
    expect(s.ultimoRx.estado, EstadoTransferencia.fallido);
    expect(s.archivosRecibidos, isEmpty);
    expect(s.archivosTmp, isEmpty);
  });

  test('cancelar el emisor a mitad -> cancelado en ambos y sin temporal', () async {
    final s = Escenario();
    addTearDown(s.cerrar);
    s.alProgreso = (r) {
      if (r.progreso > 0.3) s.emisor.cancelar();
    };
    final r = await s.enviar('grande.txt', datos(100 * 1000));
    await s.esperarRxFinal();
    expect(r.estado, EstadoTransferencia.cancelado);
    expect(s.ultimoRx.estado, EstadoTransferencia.cancelado);
    expect(s.archivosRecibidos, isEmpty);
    expect(s.archivosTmp, isEmpty);
  });

  test('cancelar el receptor a mitad -> el emisor ve cancelado', () async {
    final s = Escenario();
    addTearDown(s.cerrar);
    var pedido = false;
    s.alProgreso = (r) {
      if (r.progreso > 0.3 && !pedido) {
        pedido = true;
        unawaited(s.receptor.cancelar());
      }
    };
    final r = await s.enviar('grande.txt', datos(100 * 1000));
    await s.esperarRxFinal();
    expect(r.estado, EstadoTransferencia.cancelado, reason: r.motivo);
    expect(r.motivo, contains('receptor'));
    expect(s.ultimoRx.estado, EstadoTransferencia.cancelado);
    expect(s.archivosRecibidos, isEmpty);
    expect(s.archivosTmp, isEmpty);
  });

  test('desconexión a mitad -> fallido, sin archivo final ni temporal', () async {
    final s = Escenario();
    addTearDown(s.cerrar);
    s.alProgreso = (r) {
      if (r.progreso > 0.3 && s.ta.estadoActual == EstadoConexion.conectado) {
        s.ta.simularDesconexion();
      }
    };
    final r = await s.enviar('grande.txt', datos(100 * 1000));
    await s.esperarRxFinal();
    expect(r.estado, EstadoTransferencia.fallido);
    expect(r.motivo, contains('conexión'));
    expect(s.ultimoRx.estado, EstadoTransferencia.fallido);
    expect(s.archivosRecibidos, isEmpty);
    expect(s.archivosTmp, isEmpty);
  });

  test('el receptor rechaza -> el emisor queda cancelado y no se envían bloques', () async {
    final s = Escenario(acepta: false);
    addTearDown(s.cerrar);
    final r = await s.enviar('nota.txt', datos(100));
    expect(r.estado, EstadoTransferencia.cancelado);
    expect(r.motivo, contains('rechazada'));
    expect(s.archivosTmp, isEmpty);
    expect(s.archivosRecibidos, isEmpty);
  });

  test('nombre inválido (../x.txt): el receptor rechaza y no escribe fuera', () async {
    final s = Escenario(alterarNombre: true);
    addTearDown(s.cerrar);
    final r = await s.enviar('nota.txt', datos(100));
    await s.esperarRxFinal();
    expect(r.estado, EstadoTransferencia.cancelado);
    expect(r.motivo, contains('nombre'));
    expect(s.ultimoRx.estado, EstadoTransferencia.fallido);
    expect(File(p.join(s.raiz.path, 'x.txt')).existsSync(), isFalse);
    expect(s.archivosRecibidos, isEmpty);
  });

  test('archivo > 512 KiB lo bloquea el emisor', () async {
    final s = Escenario();
    addTearDown(s.cerrar);
    final r = await s.enviar('grande.txt', datos(512 * 1024 + 1));
    expect(r.estado, EstadoTransferencia.fallido);
    expect(r.motivo, contains('512 KiB'));
  });

  group('RepositorioHistorial', () {
    test('guarda atómico y aplica la regla de reinicio al cargar', () async {
      final dir = Directory.systemTemp.createTempSync('p6-hist-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = RepositorioHistorial(File(p.join(dir.path, 'h.json')));
      final h = HistorialTransferencias()
        ..guardar(RegistroTransferencia.nuevo(
            id: 'aaaa0001',
            direccion: DireccionTransferencia.recibido,
            nombre: 'x.txt',
            tipo: 'txt',
            longitud: Random().nextInt(100) + 1)
            .conEstado(EstadoTransferencia.enCurso));
      await repo.guardar(h);
      expect(File(p.join(dir.path, 'h.json.tmp')).existsSync(), isFalse);
      final cargado = await repo.cargar();
      expect(cargado.registros.single.estado, EstadoTransferencia.fallido);
      expect(cargado.registros.single.motivo, 'interrumpida por reinicio');
      // Persistido ya corregido.
      final otra = await RepositorioHistorial(File(p.join(dir.path, 'h.json'))).cargar();
      expect(otra.registros.single.estado, EstadoTransferencia.fallido);
    });
  });
}
