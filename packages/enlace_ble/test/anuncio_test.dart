import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('datos de fabricante caben y se decodifican', () {
    final d = datosFabricante('archivos', 0xab12);
    expect(d.length, 5);
    // flags 3 + UUID128 18 + fabricante (2 + 2 + 5) = 30 ≤ 31
    expect(3 + 18 + (2 + 2 + d.length), lessThanOrEqualTo(31));
    final r = leerDatosFabricante(idFabricantePruebas, d)!;
    expect(r.app, 'archivos');
    expect(nombreVisible(r.app, r.sufijo), 'P6-archivos-ab12');
  });

  test('datos ajenos se ignoran y el nombre iOS se interpreta', () {
    expect(leerDatosFabricante(0x004C, datosFabricante('juego', 1)), isNull);
    expect(leerDatosFabricante(idFabricantePruebas, [1, 2, 3]), isNull);
    expect(appDeNombre('P6-web-00ff'), 'web');
    expect(appDeNombre('Galaxy de Ana'), isNull);
  });
}
