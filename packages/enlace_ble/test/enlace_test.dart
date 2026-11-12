import 'dart:typed_data';

import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter_test/flutter_test.dart';

const ses = 'a1b2c3d4';
const corto = Duration(milliseconds: 40);

(Enlace, Enlace, TransporteMemoria, TransporteMemoria) crear({int mf = 20}) {
  final (a, b) = TransporteMemoria.par(maxFragmento: mf);
  return (
    Enlace(a, tiempoAck: corto, reintentos: 3),
    Enlace(b, tiempoAck: corto, reintentos: 3),
    a,
    b,
  );
}

void main() {
  test('entrega y confirma mensajes grandes', () async {
    final (ea, eb, _, _) = crear();
    final recibidos = <Sobre>[];
    eb.mensajes.listen(recibidos.add);
    final datos = {'texto': 'x' * 3000};
    final s1 = await ea.enviar(Canales.juego, ses, TiposMensaje.jugada, datos);
    final s2 = await ea.enviar(Canales.juego, ses, TiposMensaje.jugada, {'n': 1});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(s1.seq, 1);
    expect(s2.seq, 2);
    expect(recibidos.map((e) => e.seq), [1, 2]);
    expect(recibidos.first.datos['texto'], 'x' * 3000);
    await ea.cerrar();
    await eb.cerrar();
  });

  test('seq independiente por sesión; PING no espera ACK', () async {
    final (ea, eb, a, b) = crear();
    eb.mensajes.listen((_) {});
    final x = await ea.enviar(Canales.control, 'aaaaaaaa', TiposMensaje.ping, {});
    final y = await ea.enviar(Canales.control, 'bbbbbbbb', TiposMensaje.ping, {});
    expect(x.seq, 1);
    expect(y.seq, 1);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(b.enviados, 0); // sin ACK
    expect(a.enviados, greaterThanOrEqualTo(2)); // fragmentos
    await ea.cerrar();
    await eb.cerrar();
  });

  test('fragmento perdido: el reintento tiene éxito', () async {
    final (ea, eb, a, _) = crear();
    final recibidos = <Sobre>[];
    eb.mensajes.listen(recibidos.add);
    a.descartar = (f, n) => n == 1; // pierde el segundo fragmento del 1.er intento
    await ea.enviar(Canales.archivos, ses, TiposMensaje.bloque, {'b64': 'A' * 200});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recibidos.length, 1);
    await ea.cerrar();
    await eb.cerrar();
  });

  test('ACK perdido: reintento, sin duplicar entrega y con ACK reenviado', () async {
    final (ea, eb, _, b) = crear();
    final recibidos = <Sobre>[];
    eb.mensajes.listen(recibidos.add);
    b.descartar = (f, n) => n == 0; // se pierde el primer ACK
    await ea.enviar(Canales.juego, ses, TiposMensaje.jugada, {'indice': 1});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recibidos.length, 1);
    expect(b.enviados, greaterThanOrEqualTo(2)); // ACK reenviado
    await ea.cerrar();
    await eb.cerrar();
  });

  test('fragmentos duplicados no duplican el mensaje', () async {
    final (ea, eb, a, _) = crear();
    final recibidos = <Sobre>[];
    eb.mensajes.listen(recibidos.add);
    a.duplicar = (f, n) => true;
    await ea.enviar(Canales.juego, ses, TiposMensaje.jugada, {'k': 'y' * 100});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(recibidos.length, 1);
    await ea.cerrar();
    await eb.cerrar();
  });

  test('seq repetido se ignora pero se vuelve a confirmar', () async {
    final (a, b) = TransporteMemoria.par(maxFragmento: 200);
    final eb = Enlace(b, tiempoAck: corto);
    final recibidos = <Sobre>[];
    eb.mensajes.listen(recibidos.add);
    final acks = <Sobre>[];
    a.recibidos.listen((f) {
      final r = Reensamblador().agregar(f);
      if (r != null) acks.add(Sobre.fromBytes(r));
    });
    final bytes = Sobre(canal: 'juego', sesion: ses, seq: 5, tipo: 'JUGADA').toBytes();
    for (final id in [1, 2]) {
      for (final f in Fragmentador(200, idInicial: id).fragmentar(bytes)) {
        await a.enviar(f);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(recibidos.length, 1);
    expect(acks.where((s) => s.tipo == 'ACK' && s.ack == 5).length, 2);
    await eb.cerrar();
  });

  test('pérdida permanente: ErrorEnlace tras los reintentos', () async {
    final (ea, eb, a, _) = crear();
    eb.mensajes.listen((_) {});
    a.descartar = (f, n) => true;
    await expectLater(
      ea.enviar(Canales.juego, ses, TiposMensaje.jugada, {}),
      throwsA(isA<ErrorEnlace>()),
    );
    // 4 intentos (1 + 3 reintentos) de varios fragmentos cada uno
    final porIntento = a.enviados ~/ 4;
    expect(a.enviados, porIntento * 4);
    expect(porIntento, greaterThanOrEqualTo(1));
    await ea.cerrar();
    await eb.cerrar();
  });

  test('desconexión a mitad de mensaje', () async {
    final (ea, eb, a, _) = crear();
    eb.mensajes.listen((_) {});
    final estados = <EstadoConexion>[];
    ea.estado.listen(estados.add);
    a.descartar = (f, n) => n > 2; // el mensaje queda a medias
    final futuro = ea.enviar(Canales.archivos, ses, TiposMensaje.bloque, {'b64': 'A' * 500});
    final esperado = expectLater(futuro, throwsA(isA<ErrorEnlace>()));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    a.simularDesconexion();
    await esperado;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(estados, contains(EstadoConexion.desconectado));
    expect(ea.estadoActual, EstadoConexion.desconectado);
    await expectLater(
      ea.enviar(Canales.juego, ses, TiposMensaje.jugada, {}),
      throwsA(isA<ErrorEnlace>()),
    );
    await ea.cerrar();
    await eb.cerrar();
  });

  test('versión distinta: se ignora, se informa y se responde ERROR', () async {
    final (a, b) = TransporteMemoria.par(maxFragmento: 200);
    final eb = Enlace(b, tiempoAck: corto);
    final recibidos = <Sobre>[];
    final errores = <ErrorProtocolo>[];
    eb.mensajes.listen(recibidos.add);
    eb.errores.listen(errores.add);
    final respuestas = <Sobre>[];
    a.recibidos.listen((f) {
      final r = Reensamblador().agregar(f);
      if (r != null) respuestas.add(Sobre.fromBytes(r));
    });
    final malo = Uint8List.fromList(
        '{"v":2,"canal":"juego","sesion":"$ses","seq":1,"tipo":"JUGADA","ack":null,"datos":{}}'.codeUnits);
    for (final f in Fragmentador(200).fragmentar(malo)) {
      await a.enviar(f);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(recibidos, isEmpty);
    expect(errores.single.codigo, 'version');
    expect(respuestas.single.tipo, 'ERROR');
    expect(respuestas.single.datos['codigo'], 'version');
    await eb.cerrar();
  });

  test('enviar tras cerrar lanza ErrorEnlace', () async {
    final (ea, eb, _, _) = crear();
    await ea.cerrar();
    await expectLater(
      ea.enviar(Canales.juego, ses, TiposMensaje.jugada, {}),
      throwsA(isA<ErrorEnlace>()),
    );
    await eb.cerrar();
  });
}
