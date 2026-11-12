import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String nombre, List<int> bytes, [Map<String, Object?>? args]) async {
      final archivo = File('screenshots/$nombre.png');
      await archivo.create(recursive: true);
      await archivo.writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
