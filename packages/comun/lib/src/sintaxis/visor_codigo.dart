import 'package:flutter/material.dart';

import '../sintaxis/resaltador.dart';
import '../tipos/mapa_tipos.dart';

/// Visor reutilizable de texto, Markdown, JSON y XML.
///
/// El texto se limita antes de llegar aquí (las apps recortan archivos muy
/// grandes) para que la interfaz siga respondiendo. Si el JSON/XML es inválido
/// se muestra el contenido original y un aviso, nunca una pantalla en blanco.
class VisorCodigo extends StatefulWidget {
  const VisorCodigo({
    super.key,
    required this.nombre,
    required this.contenido,
    this.inicial = 0,
  });

  final String nombre;
  final String contenido;

  /// Posición inicial del ScrollController (útil para conservar la lectura).
  final double inicial;

  @override
  State<VisorCodigo> createState() => _VisorCodigoState();
}

class _VisorCodigoState extends State<VisorCodigo> {
  late final ScrollController _vertical = ScrollController(initialScrollOffset: widget.inicial);
  late ContenidoResaltado _preparado;

  @override
  void initState() {
    super.initState();
    _preparado = Resaltador.preparar(widget.nombre, widget.contenido);
  }

  @override
  void didUpdateWidget(covariant VisorCodigo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contenido != widget.contenido || oldWidget.nombre != widget.nombre) {
      _preparado = Resaltador.preparar(widget.nombre, widget.contenido);
    }
  }

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final info = MapaTipos.tipoDe(widget.nombre);
    final spans = Resaltador.spans(
      texto: _preparado.texto,
      tipo: _preparado.tipo,
      esquema: esquema,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: esquema.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(_icono(info), size: 18, color: esquema.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${info.descripcion} · ${info.mime}',
                  style: Theme.of(context).textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${_preparado.texto.length} caracteres',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        if (_preparado.error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: esquema.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: esquema.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _preparado.error!,
                    style: TextStyle(color: esquema.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Scrollbar(
            controller: _vertical,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _vertical,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                    children: spans,
                  ),
                  key: const Key('visor-codigo-texto'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _icono(InfoTipo info) {
    if (info.esJson) return Icons.data_object;
    if (info.esXml) return Icons.code;
    if (info.esImagen) return Icons.image_outlined;
    return Icons.description_outlined;
  }
}
