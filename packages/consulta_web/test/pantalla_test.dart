import 'dart:async';

import 'package:consulta_web/consulta_web.dart';
import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PuenteFalso implements PuenteBle {
  EstadoBluetooth bt = EstadoBluetooth.encendido;
  final _c = StreamController<TransporteBytes>.broadcast();
  int iniciados = 0;

  @override
  Future<void> abrirAjustes(RolBle rol) async {}
  @override
  Future<TransporteBytes?> conectar(String id) async => null;
  @override
  Stream<TransporteBytes> get conexionesServidor => _c.stream;
  @override
  Future<void> desconectar() async {}
  @override
  Future<void> detenerServidor() async {}
  @override
  Future<void> dispose() async {}
  @override
  Stream<DispositivoEncontrado> escanear() => const Stream.empty();
  @override
  Future<EstadoBluetooth> iniciarServidor() async {
    iniciados++;
    return bt;
  }

  @override
  String? get mensajeError => null;
  @override
  String get nombreAnuncio => 'P6-web-test';
  @override
  Future<EstadoBluetooth> prepararCliente() async => bt;
}

void main() {
  testWidgets('selector de rol y vista de servidor', (t) async {
    final p = PuenteFalso();
    await t.pumpWidget(MaterialApp(
        home: PantallaConsultaWeb(puente: p, almacen: AlmacenMemoria())));
    expect(find.text('A: tiene Internet y hace las peticiones HTTPS.'), findsOneWidget);
    expect(find.textContaining('B: sin Wi'), findsOneWidget);

    await t.tap(find.byKey(const Key('rol-servidor')));
    await t.pumpAndSettle();
    expect(p.iniciados, 1);
    expect(find.text('Estado: Esperando a un cliente'), findsOneWidget);
    expect(find.byKey(const Key('switch-retraso')), findsOneWidget);
    expect(find.text('httpbin.org'), findsOneWidget);
  });

  testWidgets('cliente con Bluetooth apagado muestra el aviso', (t) async {
    final p = PuenteFalso()..bt = EstadoBluetooth.apagado;
    await t.pumpWidget(MaterialApp(
        home: PantallaConsultaWeb(puente: p, almacen: AlmacenMemoria())));
    await t.tap(find.byKey(const Key('rol-cliente')));
    await t.pumpAndSettle();
    expect(find.textContaining('Bluetooth está apagado'), findsOneWidget);
    expect(find.byKey(const Key('barra-direccion')), findsOneWidget);
  });
}
