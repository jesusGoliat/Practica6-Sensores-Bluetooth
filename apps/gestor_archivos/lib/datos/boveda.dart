import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../dominio/modelos.dart';
import 'servicio_archivos.dart';

/// Carpeta `protegido/` del espacio privado. Se bloquea al salir/pausar.
class EstadoBoveda extends ChangeNotifier {
  EstadoBoveda({required this.documentos, required this.servicio});

  static const String nombreCarpeta = 'protegido';

  final Directory documentos;
  final ServicioArchivos servicio;
  bool _desbloqueada = false;

  bool get desbloqueada => _desbloqueada;
  String get ruta => p.join(documentos.path, nombreCarpeta);

  RaizAutorizada get raiz => RaizAutorizada(
        id: 'privado',
        nombre: 'Espacio de la app',
        origen: OrigenArchivo.privado,
        referencia: documentos.path,
      );

  void desbloquear() {
    _desbloqueada = true;
    notifyListeners();
  }

  void bloquear() {
    if (!_desbloqueada) return;
    _desbloqueada = false;
    notifyListeners();
  }

  /// Crea la carpeta y una nota de ejemplo si no existe. Solo con la bóveda desbloqueada.
  Future<void> asegurar() async {
    final d = Directory(ruta);
    if (!d.existsSync()) {
      await d.create(recursive: true);
      await File(p.join(ruta, 'nota_privada.txt'))
          .writeAsString('Contenido de ejemplo de la Bóveda.');
    }
  }

  /// Listado; lanza si la bóveda está bloqueada (nunca devuelve datos sin autenticar).
  Future<List<EntradaArchivo>> listar() async {
    if (!_desbloqueada) throw StateError('Bóveda bloqueada');
    await asegurar();
    return servicio.listar(raiz, ruta);
  }

  Future<void> moverAqui(EntradaArchivo entrada) async {
    await Directory(ruta).create(recursive: true);
    await servicio.mover(entrada, raiz, ruta);
  }
}
