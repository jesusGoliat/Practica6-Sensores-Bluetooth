import 'dart:typed_data';

import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List datos(int n) => Uint8List.fromList(List.generate(n, (i) => (i * 7 + 3) & 0xFF));

void main() {
  group('Fragmentador / Reensamblador', () {
    for (final mf in [20, 23, 182, 512]) {
      for (final n in [0, 1, 14, 15, 16, 1000, 65536]) {
        test('ida y vuelta maxFragmento=$mf, $n B', () {
          final f = Fragmentador(mf);
          final r = Reensamblador();
          final frags = f.fragmentar(datos(n));
          expect(frags.every((x) => x.length <= mf), isTrue);
          expect((frags.last[0] & 1), 1);
          Uint8List? salida;
          for (final x in frags) {
            salida = r.agregar(x);
          }
          expect(salida, datos(n));
          expect(r.pendientes, 0);
        });
      }
    }

    test('rechaza maxFragmento <= 5', () {
      expect(() => Fragmentador(5), throwsArgumentError);
      expect(() => Fragmentador(6), returnsNormally);
    });

    test('rechaza más de 64 KiB al fragmentar', () {
      expect(() => Fragmentador(20).fragmentar(datos(65537)), throwsA(isA<ErrorProtocolo>()));
    });

    test('msgId da la vuelta en 65535', () {
      final f = Fragmentador(20, idInicial: 65535);
      final a = f.fragmentar(datos(1)).first;
      final b = f.fragmentar(datos(1)).first;
      expect((a[1] << 8) | a[2], 65535);
      expect((b[1] << 8) | b[2], 0);
    });

    test('cabecera big endian', () {
      final f = Fragmentador(6, idInicial: 0x0102);
      final frags = f.fragmentar(datos(300));
      expect(frags[258].sublist(1, 5), [0x01, 0x02, 0x01, 0x02]);
    });

    test('ignora fragmento duplicado', () {
      final frags = Fragmentador(20).fragmentar(datos(100));
      final r = Reensamblador();
      r.agregar(frags[0]);
      r.agregar(frags[0]);
      Uint8List? out;
      for (final x in frags.skip(1)) {
        out = r.agregar(x);
      }
      expect(out, datos(100));
    });

    test('rechaza fuera de orden y descarta el parcial', () {
      final frags = Fragmentador(20).fragmentar(datos(100));
      final r = Reensamblador();
      r.agregar(frags[0]);
      expect(() => r.agregar(frags[2]), throwsA(isA<ErrorProtocolo>()));
      expect(r.pendientes, 0);
      expect(() => r.agregar(frags[1]), throwsA(isA<ErrorProtocolo>()));
    });

    test('rechaza fragmento corto', () {
      expect(() => Reensamblador().agregar(Uint8List(3)), throwsA(isA<ErrorProtocolo>()));
    });

    test('descarta incompletos tras el tiempo límite', () {
      var ahora = DateTime(2026);
      final r = Reensamblador(reloj: () => ahora);
      final frags = Fragmentador(20).fragmentar(datos(100));
      r.agregar(frags[0]);
      expect(r.pendientes, 1);
      ahora = ahora.add(const Duration(seconds: 11));
      expect(() => r.agregar(frags[1]), throwsA(isA<ErrorProtocolo>()));
      expect(r.pendientes, 0);
    });

    test('limita el reensamblado a 64 KiB', () {
      final r = Reensamblador();
      Uint8List frag(int i, bool ultimo) {
        final f = Uint8List(5 + 1000);
        f[0] = ultimo ? 1 : 0;
        f[3] = i >> 8;
        f[4] = i & 0xFF;
        return f;
      }

      expect(() {
        for (var i = 0; i < 70; i++) {
          r.agregar(frag(i, false));
        }
      }, throwsA(isA<ErrorProtocolo>()));
      expect(r.pendientes, 0);
    });
  });

  group('ControlDuplicados', () {
    test('detecta repetidos por canal/sesión', () {
      final c = ControlDuplicados();
      expect(c.esNuevo('juego', 'aaaaaaaa', 1), isTrue);
      expect(c.esNuevo('juego', 'aaaaaaaa', 1), isFalse);
      expect(c.esNuevo('juego', 'bbbbbbbb', 1), isTrue);
      expect(c.esNuevo('web', 'aaaaaaaa', 1), isTrue);
    });

    test('memoria acotada', () {
      final c = ControlDuplicados(porSesion: 4, maxSesiones: 2);
      for (var i = 0; i < 10; i++) {
        c.esNuevo('juego', 'aaaaaaaa', i);
      }
      expect(c.esNuevo('juego', 'aaaaaaaa', 9), isFalse);
      expect(c.esNuevo('juego', 'aaaaaaaa', 0), isTrue); // olvidado
      c.esNuevo('juego', 'bbbbbbbb', 1);
      c.esNuevo('juego', 'cccccccc', 1);
      expect(c.esNuevo('juego', 'bbbbbbbb', 1), isFalse);
    });
  });
}
