import 'dart:io';

import 'package:path/path.dart' as p;

import 'ajustes_app.dart';
import 'boveda.dart';
import 'repositorio_ubicaciones.dart';
import 'servicio_archivos.dart';
import 'servicio_biometria.dart';
import 'servicio_sensores.dart';
import 'transferencia/estado_transferencias.dart';
import 'transferencia/puente_ble.dart';
import 'transferencia/repositorio_historial.dart';

/// Servicios de la Práctica 6 agrupados para inyectarlos en la app.
class ServiciosP6 {
  ServiciosP6({
    required this.ajustes,
    required this.transferencias,
    required this.autenticador,
    required this.boveda,
    required this.sensores,
  });

  final AjustesApp ajustes;
  final EstadoTransferencias transferencias;
  final Autenticador autenticador;
  final EstadoBoveda boveda;
  final ServicioSensores sensores;

  /// [documentos] = espacio privado (visible en el explorador); [soporte] =
  /// carpeta interna para historial y temporales.
  static ServiciosP6 crear({
    required PreferenciasApp preferencias,
    required Directory documentos,
    required Directory soporte,
    required ServicioArchivos servicioPrivado,
    Autenticador? autenticador,
    PuenteBle? puente,
  }) {
    final ajustes = AjustesApp(preferencias);
    return ServiciosP6(
      ajustes: ajustes,
      transferencias: EstadoTransferencias(
        repositorio: RepositorioHistorial(File(p.join(soporte.path, 'historial_transferencias.json'))),
        directorioRecibidos: Directory(p.join(documentos.path, 'recibidos')),
        directorioTmp: Directory(p.join(soporte.path, 'tmp')),
        ajustes: ajustes,
        puente: puente,
      ),
      autenticador: autenticador ?? ServicioBiometria(),
      boveda: EstadoBoveda(documentos: documentos, servicio: servicioPrivado),
      sensores: ServicioSensores(ajustes),
    );
  }
}
