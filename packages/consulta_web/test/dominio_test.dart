import 'dart:typed_data';
import 'dart:io';

import 'package:consulta_web/consulta_web.dart';
import 'package:flutter_test/flutter_test.dart';

ValidadorDestino validadorCon(List<String> ips) => ValidadorDestino(
      resolver: (h) async => [for (final i in ips) InternetAddress(i)],
    );

void main() {
  group('ValidadorDestino', () {
    final v = validadorCon(['93.184.216.34']);

    test('permite recursos de la lista blanca', () async {
      for (final r in ListaBlanca.contrato.recursos) {
        expect((await v.validar(r.url)).ok, isTrue, reason: r.url);
      }
    });
    test('rechaza http', () async {
      expect((await v.validar('http://httpbin.org/json')).motivo, MotivoRechazo.esquema);
    });
    test('rechaza otro dominio', () async {
      expect((await v.validar('https://example.com/')).motivo, MotivoRechazo.dominio);
    });
    test('rechaza userinfo', () async {
      expect((await v.validar('https://user:pw@httpbin.org/json')).motivo,
          MotivoRechazo.credenciales);
      expect((await v.validar('https://httpbin.org@example.com/')).motivo,
          MotivoRechazo.credenciales);
    });
    test('rechaza IP literal y localhost', () async {
      expect((await v.validar('https://192.168.1.1/')).motivo, MotivoRechazo.ipLiteral);
      expect((await v.validar('https://[::1]/')).motivo, MotivoRechazo.ipLiteral);
      expect((await v.validar('https://localhost/')).motivo, MotivoRechazo.dominio);
    });
    test('rechaza puerto distinto de 443', () async {
      expect((await v.validar('https://httpbin.org:8443/json')).motivo, MotivoRechazo.puerto);
      expect((await v.validar('https://httpbin.org:443/json')).ok, isTrue);
    });
    test('rechaza host que resuelve a direcciones privadas', () async {
      for (final ip in [
        '10.0.0.5', '172.16.0.1', '172.31.255.1', '192.168.0.9', '127.0.0.1',
        '169.254.1.1', '100.64.0.1', '::1', 'fc00::1', 'fd12::1', 'fe80::1',
        '::ffff:10.0.0.1',
      ]) {
        final r = await validadorCon([ip]).validar('https://httpbin.org/json');
        expect(r.motivo, MotivoRechazo.destinoPrivado, reason: ip);
      }
      // Una sola privada entre varias públicas basta.
      expect((await validadorCon(['8.8.8.8', '10.1.1.1']).validar('https://httpbin.org/')).ok,
          isFalse);
      expect((await validadorCon(['172.32.0.1', '100.128.0.1']).validar('https://httpbin.org/')).ok,
          isTrue);
    });
    test('falla de DNS se propaga como SocketException', () {
      final f = ValidadorDestino(resolver: (_) async => throw const SocketException('x'));
      expect(f.validar('https://httpbin.org/'), throwsA(isA<SocketException>()));
    });
  });

  group('LimitadorPeticiones', () {
    test('10 por minuto con ventana deslizante', () {
      var t = DateTime(2026, 1, 1);
      final l = LimitadorPeticiones(reloj: () => t);
      for (var i = 0; i < 10; i++) {
        expect(l.intentar(), isTrue);
        t = t.add(const Duration(seconds: 1));
      }
      expect(l.intentar(), isFalse);
      t = DateTime(2026, 1, 1, 0, 1, 0); // sale la 1.ª (t=0)
      expect(l.intentar(), isTrue);
      expect(l.intentar(), isFalse);
    });
  });

  group('CacheWeb', () {
    EntradaCache e(String u) => EntradaCache(
        url: u, tipo: 'text/plain', estado: 200, fecha: DateTime.utc(2026), texto: 'x');

    test('LRU con máximo 30', () async {
      final c = CacheWeb();
      for (var i = 0; i < 30; i++) {
        await c.guardar(e('u$i'));
      }
      c.obtener('u0'); // u0 pasa a ser la más reciente
      await c.guardar(e('nueva'));
      expect(c.longitud, 30);
      expect(c.mirar('u0'), isNotNull);
      expect(c.mirar('u1'), isNull);
    });
    test('persiste en JSON con bytes', () async {
      final a = AlmacenMemoria();
      final c = CacheWeb(almacen: a);
      await c.guardar(EntradaCache(
          url: 'i', tipo: 'image/png', estado: 200, fecha: DateTime.utc(2026), bytes: Uint8List.fromList([1, 2, 3])));
      await c.guardar(e('t'));
      final c2 = CacheWeb(almacen: a);
      await c2.cargar();
      expect(c2.longitud, 2);
      expect(c2.mirar('i')!.bytes, [1, 2, 3]);
      expect(c2.mirar('t')!.texto, 'x');
    });
    test('datos corruptos no rompen', () async {
      final a = AlmacenMemoria()..datos[CacheWeb.clave] = '{no json';
      final c = CacheWeb(almacen: a);
      await c.cargar();
      expect(c.longitud, 0);
    });
  });

  group('HistorialNavegacion', () {
    test('atrás, adelante y truncado', () {
      final h = HistorialNavegacion();
      h.visitar('a');
      h.visitar('b');
      h.visitar('c');
      expect(h.atras(), 'b');
      expect(h.atras(), 'a');
      expect(h.atras(), isNull);
      expect(h.adelante(), 'b');
      h.visitar('d'); // descarta c
      expect(h.puedeAdelante, isFalse);
      expect(h.urls, ['a', 'b', 'd']);
      h.visitar('d');
      expect(h.urls.length, 3);
    });
  });

  test('Favoritos persisten', () async {
    final a = AlmacenMemoria();
    final f = Favoritos(almacen: a);
    await f.alternar('x');
    await f.alternar('y');
    await f.alternar('x');
    final g = Favoritos(almacen: a);
    await g.cargar();
    expect(g.urls, ['y']);
  });
}
