import 'dart:typed_data';

import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/acciones_archivo.dart';
import '../datos/estado_gestor.dart';
import '../dominio/modelos.dart';
import 'hoja_metadatos.dart';
import 'widgets/dialogo_tema.dart';

/// Visor de texto, JSON, XML, Markdown e imágenes.
class PantallaVisor extends StatelessWidget {
  const PantallaVisor({super.key, required this.archivo});

  final ArchivoAbierto archivo;

  @override
  Widget build(BuildContext context) {
    final entrada = archivo.entrada;
    final tipo = MapaTipos.tipoDe(entrada.nombre);
    final gestor = context.read<EstadoGestor>();
    final acciones = context.read<AccionesArchivo>();
    final servicio = gestor.servicioDe(entrada);
    return Scaffold(
      appBar: AppBar(
        title: Text(entrada.nombre, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('visor-favorito'),
            tooltip: T.favoritos,
            onPressed: () => gestor.alternarFavorito(entrada),
            icon: Icon(gestor.esFavorito(entrada) ? Icons.star : Icons.star_border),
          ),
          IconButton(
            key: const Key('visor-metadatos'),
            tooltip: T.metadatos,
            onPressed: () => mostrarMetadatos(context, entrada),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            key: const Key('visor-compartir'),
            tooltip: T.compartir,
            onPressed: () => ejecutarSeguro(context, () => acciones.compartir(entrada, servicio)),
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            key: const Key('visor-exportar'),
            tooltip: T.exportar,
            onPressed: () => ejecutarSeguro(context, () async {
              final guardado = await acciones.exportar(entrada, servicio);
              if (guardado && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copia exportada correctamente.')),
                );
              }
            }),
            icon: const Icon(Icons.save_alt),
          ),
        ],
      ),
      body: tipo.esImagen
          ? VisorImagen(bytes: archivo.bytes, nombre: entrada.nombre)
          : VisorCodigo(
              nombre: entrada.nombre,
              contenido: archivo.texto ?? '',
            ),
    );
  }
}

/// Visor de imagen con zoom, paneo, doble toque para restablecer y rotación.
class VisorImagen extends StatefulWidget {
  const VisorImagen({super.key, required this.bytes, required this.nombre});

  final Uint8List bytes;
  final String nombre;

  @override
  State<VisorImagen> createState() => _VisorImagenState();
}

class _VisorImagenState extends State<VisorImagen> {
  final TransformationController _control = TransformationController();
  int _giro = 0;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _reiniciar() {
    _control.value = Matrix4.identity();
    setState(() => _giro = 0);
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onDoubleTap: _reiniciar,
            child: InteractiveViewer(
              transformationController: _control,
              minScale: 0.5,
              maxScale: 8,
              boundaryMargin: const EdgeInsets.all(80),
              child: Center(
                child: RotatedBox(
                  quarterTurns: _giro,
                  child: Image.memory(
                    widget.bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (contexto, error, stack) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined, size: 72, color: esquema.error),
                        const SizedBox(height: 12),
                        const Text('La imagen no se pudo decodificar.'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: esquema.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.pinch_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pellizca para zoom, arrastra para mover, doble toque para restablecer.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              IconButton(
                key: const Key('imagen-girar'),
                tooltip: 'Girar 90°',
                onPressed: () => setState(() => _giro = (_giro + 1) % 4),
                icon: const Icon(Icons.rotate_right),
              ),
              IconButton(
                key: const Key('imagen-reiniciar'),
                tooltip: 'Restablecer',
                onPressed: _reiniciar,
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
