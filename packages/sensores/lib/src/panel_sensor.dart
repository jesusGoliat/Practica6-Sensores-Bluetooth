import 'package:flutter/material.dart';

import 'controlador.dart';
import 'modelo.dart';

/// Texto en español de un [EstadoSensor].
String textoEstado(EstadoSensor e) => switch (e) {
      EstadoSensor.inactivo => 'Inactivo',
      EstadoSensor.escuchando => 'Escuchando',
      EstadoSensor.pausado => 'En pausa',
      EstadoSensor.ausente => 'Sensor ausente en este dispositivo',
      EstadoSensor.sinDatos => 'Sin datos',
      EstadoSensor.error => 'Error del sensor',
    };

String _dos(int n) => n.toString().padLeft(2, '0');

/// Formatea un instante como HH:mm:ss.SSS.
String formatoInstante(DateTime t) =>
    '${_dos(t.hour)}:${_dos(t.minute)}:${_dos(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';

/// Muestra la última lectura y el estado de un sensor.
class PanelSensor extends StatelessWidget {
  const PanelSensor({
    super.key,
    required this.tipo,
    required this.estado,
    this.lectura,
    this.origen,
  });

  /// Panel que se reconstruye al notificar [controlador].
  static Widget deControlador(ControladorSensor controlador, {Key? key}) =>
      ListenableBuilder(
        key: key,
        listenable: controlador,
        builder: (_, _) => PanelSensor(
            tipo: controlador.fuente.tipo,
            estado: controlador.estado,
            lectura: controlador.ultima,
            origen: controlador.fuente.origen),
      );

  final TipoSensor tipo;
  final EstadoSensor estado;
  final LecturaSensor? lectura;

  /// Origen; por omisión el de [lectura].
  final OrigenLectura? origen;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final l = lectura;
    final origen = this.origen ?? l?.origen;
    final simulada = origen == OrigenLectura.simulada;
    final unidad = tipo.unidad;
    String v(double d) => d.toStringAsFixed(2);
    final descripcion = l == null
        ? '${tipo.nombre}: ${textoEstado(estado)}, sin lecturas'
        : '${tipo.nombre}: x ${v(l.x)}, y ${v(l.y)}, z ${v(l.z)} $unidad, '
            'magnitud ${v(l.magnitud)}, ${textoEstado(estado)}, '
            '${simulada ? 'simulada' : 'física'}';
    return Semantics(
      container: true,
      label: descripcion,
      child: ExcludeSemantics(
        child: Card(
          color: esquema.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(tipo.nombre,
                          style: texto.titleMedium
                              ?.copyWith(color: esquema.onSurface))),
                  if (origen != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: simulada
                              ? esquema.tertiaryContainer
                              : esquema.primaryContainer,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(simulada ? 'SIMULADA' : 'FÍSICA',
                          style: texto.labelMedium?.copyWith(
                              color: simulada
                                  ? esquema.onTertiaryContainer
                                  : esquema.onPrimaryContainer)),
                    ),
                ]),
                const SizedBox(height: 8),
                if (l == null)
                  Text('Sin lecturas', style: texto.bodyMedium)
                else ...[
                  Text('x: ${v(l.x)} $unidad'),
                  Text('y: ${v(l.y)} $unidad'),
                  Text('z: ${v(l.z)} $unidad'),
                  Text('Magnitud: ${v(l.magnitud)} $unidad'),
                  Text('Instante: ${formatoInstante(l.instante)}'),
                ],
                const SizedBox(height: 8),
                Text('Estado: ${textoEstado(estado)}',
                    style: texto.bodyMedium?.copyWith(
                        color: estado == EstadoSensor.error ||
                                estado == EstadoSensor.ausente
                            ? esquema.error
                            : esquema.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
