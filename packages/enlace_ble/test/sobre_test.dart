import 'dart:convert';
import 'dart:typed_data';

import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List json(Object o) => Uint8List.fromList(utf8.encode(jsonEncode(o)));

String codigo(Uint8List b) {
  try {
    Sobre.fromBytes(b);
  } on ErrorProtocolo catch (e) {
    return e.codigo;
  }
  return 'ok';
}

Map<String, dynamic> base() => {
  'v': 1,
  'canal': 'juego',
  'sesion': 'a1b2c3d4',
  'seq': 17,
  'tipo': 'JUGADA',
  'ack': null,
  'datos': {'indice': 3},
};

void main() {
  test('ida y vuelta', () {
    final s = Sobre(
      canal: 'juego',
      sesion: 'a1b2c3d4',
      seq: 17,
      tipo: 'JUGADA',
      datos: {'indice': 3, 'ñ': 'é'},
    );
    final r = Sobre.fromBytes(s.toBytes());
    expect(r.canal, 'juego');
    expect(r.seq, 17);
    expect(r.datos['ñ'], 'é');
    expect(r.ack, isNull);
  });

  test('versión distinta', () {
    expect(codigo(json({...base(), 'v': 2})), 'version');
  });

  test('formato inválido', () {
    expect(codigo(Uint8List.fromList(utf8.encode('{no'))), 'formato');
    expect(codigo(Uint8List.fromList([0xff, 0xfe])), 'formato');
    expect(codigo(json([1, 2])), 'formato');
  });

  test('campos inválidos', () {
    expect(codigo(json({...base(), 'canal': 'otro'})), 'campo');
    expect(codigo(json({...base(), 'sesion': 'xyz'})), 'campo');
    expect(codigo(json({...base(), 'seq': -1})), 'campo');
    expect(codigo(json({...base(), 'seq': '1'})), 'campo');
    expect(codigo(json({...base(), 'tipo': 'jugada'})), 'campo');
    expect(codigo(json({...base(), 'datos': 5})), 'campo');
    expect(codigo(json({...base(), 'tipo': 'ACK'})), 'campo');
    expect(codigo(json(base()..remove('v'))), 'campo');
    expect(codigo(json(base())), 'ok');
  });

  test('constantes', () {
    expect(TiposMensaje.esConfiable('JUGADA'), isTrue);
    expect(TiposMensaje.esConfiable('ACK'), isFalse);
    expect(TiposMensaje.esConfiable('PING'), isFalse);
    expect(Sobre.nuevaSesion(), matches(RegExp(r'^[0-9a-f]{8}$')));
  });
}
