import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:consulta_web/consulta_web.dart';
import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter_test/flutter_test.dart';

class HttpFalso implements ClienteHttp {
  final Map<String, RespuestaHttp Function()> rutas = {};
  final List<Uri> pedidos = [];
  Duration demora = Duration.zero;
  Object? falla;

  @override
  Future<RespuestaHttp> obtener(Uri uri, {required int maxBytes}) async {
    pedidos.add(uri);
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (falla != null) throw falla!;
    final r = rutas[uri.toString()];
    if (r == null) return RespuestaHttp(estado: 404, tipoContenido: 'text/plain', cuerpo: Uint8List(0));
    return r();
  }
}

RespuestaHttp texto(String s, [String tipo = 'application/json']) => RespuestaHttp(
    estado: 200, tipoContenido: '$tipo; charset=utf-8', cuerpo: Uint8List.fromList(utf8.encode(s)));

RespuestaHttp redir(String a) =>
    RespuestaHttp(estado: 302, ubicacion: a, cuerpo: Uint8List(0));

const todo = 'https://jsonplaceholder.typicode.com/todos/1';

ServidorConsulta crear(HttpFalso h,
    {Duration limite = const Duration(seconds: 10),
    Duration retraso = const Duration(seconds: 12),
    DateTime Function()? reloj}) {
  return ServidorConsulta(
    http: h,
    validador: ValidadorDestino(resolver: (_) async => [InternetAddress('93.184.216.34')]),
    tiempoLimite: limite,
    retrasoDiag: retraso,
    reloj: reloj,
  );
}

void main() {
  group('ServidorConsulta', () {
    test('JSON correcto', () async {
      final h = HttpFalso()..rutas[todo] = () => texto('{"id":1}');
      final m = await crear(h).atender('r1', todo);
      expect(m.tipo, TiposMensaje.respuesta);
      expect(m.datos['estado'], 200);
      expect(m.datos['tipo'], 'application/json');
      expect(m.datos['cuerpo'], '{"id":1}');
      expect(m.datos['bytes'], 8);
      expect(m.datos['urlFinal'], todo);
      expect(m.datos['fecha'], isNotNull);
    });

    test('destino rechazado sin abrir conexión', () async {
      final h = HttpFalso();
      final m = await crear(h).atender('r1', 'https://example.com/');
      expect(m.datos['codigo'], 'destino_rechazado');
      expect(m.datos['req'], 'r1');
      expect(h.pedidos, isEmpty);
    });

    test('redirección a destino no permitido', () async {
      final h = HttpFalso()
        ..rutas['https://httpbin.org/redirect-to'] = (() => redir('http://127.0.0.1/'));
      final m = await crear(h).atender('r1', 'https://httpbin.org/redirect-to');
      expect(m.datos['codigo'], 'destino_rechazado');
      expect(h.pedidos.length, 1);
    });

    test('redirección válida se sigue; cadena >3 se rechaza', () async {
      final h = HttpFalso()
        ..rutas['https://httpbin.org/a'] = (() => redir('/b'))
        ..rutas['https://httpbin.org/b'] = () => texto('ok', 'text/plain');
      var m = await crear(h).atender('r1', 'https://httpbin.org/a');
      expect(m.datos['urlFinal'], 'https://httpbin.org/b');
      expect(m.datos['cuerpo'], 'ok');

      final c = HttpFalso();
      for (var i = 0; i < 6; i++) {
        c.rutas['https://httpbin.org/$i'] = () => redir('/${i + 1}');
      }
      m = await crear(c).atender('r2', 'https://httpbin.org/0');
      expect(m.datos['codigo'], 'destino_rechazado');
      expect(m.datos['motivo'], 'demasiadasRedirecciones');
      expect(c.pedidos.length, 4); // original + 3 saltos
    });

    test('timeout con retraso diagnóstico', () async {
      final h = HttpFalso()..rutas[todo] = () => texto('{}');
      final s = crear(h,
          limite: const Duration(milliseconds: 100), retraso: const Duration(milliseconds: 300))
        ..retrasoDiagnostico = true;
      final m = await s.atender('r1', todo);
      expect(m.datos['codigo'], 'timeout');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(h.pedidos, isEmpty, reason: 'no debe salir tras vencer el plazo');
    });

    test('timeout por servidor lento', () async {
      final h = HttpFalso()
        ..demora = const Duration(milliseconds: 300)
        ..rutas[todo] = () => texto('{}');
      final m = await crear(h, limite: const Duration(milliseconds: 100)).atender('r1', todo);
      expect(m.datos['codigo'], 'timeout');
    });

    test('sin Internet (SocketException en HTTP o DNS)', () async {
      final h = HttpFalso()..falla = const SocketException('sin red');
      expect((await crear(h).atender('r1', todo)).datos['codigo'], 'sin_internet');
      final s = ServidorConsulta(
        http: HttpFalso(),
        validador: ValidadorDestino(resolver: (_) async => throw const SocketException('dns')),
      );
      expect((await s.atender('r2', todo)).datos['codigo'], 'sin_internet');
    });

    test('demasiado grande', () async {
      final h = HttpFalso()
        ..rutas[todo] = (() => RespuestaHttp(
            estado: 200, tipoContenido: 'text/plain', cuerpo: Uint8List(10), excedido: true));
      expect((await crear(h).atender('r1', todo)).datos['codigo'], 'demasiado_grande');
      final h2 = HttpFalso()..rutas[todo] = () => texto('a' * 70000, 'text/plain');
      expect((await crear(h2).atender('r1', todo)).datos['codigo'], 'demasiado_grande');
    });

    test('imagen y formato no admitido', () async {
      final h = HttpFalso()
        ..rutas[todo] = (() => RespuestaHttp(
            estado: 200, tipoContenido: 'image/jpeg', cuerpo: Uint8List.fromList([1, 2, 3])))
        ..rutas['https://httpbin.org/grande'] = (() => RespuestaHttp(
            estado: 200, tipoContenido: 'image/png', cuerpo: Uint8List(65 * 1024)))
        ..rutas['https://httpbin.org/pdf'] = (() => RespuestaHttp(
            estado: 200, tipoContenido: 'application/pdf', cuerpo: Uint8List(5)));
      final s = crear(h);
      final m = await s.atender('r1', todo);
      expect(base64Decode(m.datos['b64'] as String), [1, 2, 3]);
      expect(m.datos.containsKey('cuerpo'), isFalse);
      expect((await s.atender('r2', 'https://httpbin.org/grande')).datos['codigo'],
          'formato_no_admitido');
      expect((await s.atender('r3', 'https://httpbin.org/pdf')).datos['codigo'],
          'formato_no_admitido');
    });

    test('req duplicada no vuelve a pedir', () async {
      final h = HttpFalso()..rutas[todo] = () => texto('{}');
      final s = crear(h);
      final a = await s.atender('r1', todo);
      final b = await s.atender('r1', todo);
      expect(identical(a, b), isTrue);
      expect(h.pedidos.length, 1);
      await Future<void>.delayed(Duration.zero);
      expect(s.registro.where((r) => r.duplicada).length, 1);
    });

    test('límite de 10 por minuto', () async {
      final h = HttpFalso()..rutas[todo] = () => texto('{}');
      final s = crear(h, reloj: () => DateTime(2026));
      for (var i = 0; i < 10; i++) {
        expect((await s.atender('r$i', todo)).esError, isFalse);
      }
      expect((await s.atender('r10', todo)).datos['codigo'], 'limite');
    });
  });

  group('ClienteConsulta de extremo a extremo', () {
    late TransporteMemoria ta, tb;
    late Enlace ea, eb;
    late HttpFalso http;
    late ServidorConsulta servidor;
    late ClienteConsulta cliente;

    setUp(() {
      (ta, tb) = TransporteMemoria.par(maxFragmento: 200);
      ea = Enlace(ta);
      eb = Enlace(tb);
      http = HttpFalso()..rutas[todo] = () => texto('{"id":1,"title":"x"}');
      servidor = crear(http)..vincular(ea);
      cliente = ClienteConsulta(cache: CacheWeb(), tiempoEspera: const Duration(seconds: 3))
        ..conectar(eb);
    });
    tearDown(() async {
      cliente.dispose();
      servidor.dispose();
      await ea.cerrar();
      await eb.cerrar();
    });

    test('RED, luego CACHÉ al perder el enlace y error para URL nueva', () async {
      final r = await cliente.consultar(todo);
      expect(r.ok, isTrue);
      expect(r.origen, OrigenRespuesta.red);
      expect(r.estado, 200);
      expect(r.texto, contains('title'));

      ta.simularDesconexion();
      await Future<void>.delayed(Duration.zero);
      final c = await cliente.consultar(todo);
      expect(c.origen, OrigenRespuesta.cache);
      expect(c.fecha, r.fecha);
      expect(c.aviso, isNotNull);
      final n = await cliente.consultar('https://httpbin.org/uuid');
      expect(n.ok, isFalse);
      expect(n.error, contains('caché'));
      expect(http.pedidos.length, 1);
    });

    test('error del servidor llega al cliente y no usa caché', () async {
      final r = await cliente.consultar('https://example.com/');
      expect(r.ok, isFalse);
      expect(r.codigoError, 'destino_rechazado');
    });

    test('ignora respuestas desconocidas o duplicadas', () async {
      final r = await cliente.consultar(todo, req: 'fija');
      expect(r.ok, isTrue);
      // Respuesta tardía para una req ya resuelta: no debe fallar ni cambiar nada.
      await ea.enviar(Canales.web, '11111111', TiposMensaje.respuesta, {
        'req': 'fija', 'estado': 500, 'tipo': 'text/plain', 'cuerpo': 'x',
        'fecha': DateTime.now().toIso8601String(),
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final c = await cliente.consultar(todo);
      expect(c.estado, 200);
    });

    test('timeout del cliente recurre a la caché', () async {
      final lento = ClienteConsulta(
          cache: CacheWeb(), tiempoEspera: const Duration(milliseconds: 150))
        ..conectar(eb);
      http.demora = const Duration(seconds: 2);
      servidor.soltar();
      final r = await lento.consultar(todo);
      expect(r.ok, isFalse);
      lento.dispose();
    });
  });
}
