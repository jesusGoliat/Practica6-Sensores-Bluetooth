import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_gestor.dart';
import '../dominio/modelos.dart';

/// Vista de árbol de la carpeta actual, con profundidad y número de entradas
/// limitados para no bloquear la interfaz en carpetas enormes.
class ArbolCarpetas extends StatefulWidget {
  const ArbolCarpetas({super.key, required this.raiz, required this.referencia});

  final RaizAutorizada raiz;
  final String referencia;

  @override
  State<ArbolCarpetas> createState() => _ArbolCarpetasState();
}

class _ArbolCarpetasState extends State<ArbolCarpetas> {
  late final EstadoGestor _gestor = context.read<EstadoGestor>();
  List<String> _lineas = <String>[];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _construir();
  }

  Future<void> _construir() async {
    final lineas = <String>[];
    final servicio = _gestor.servicioDeRaiz(widget.raiz);
    Future<void> recorrer(String ref, int nivel) async {
      if (nivel > 4 || lineas.length > 200) return;
      final entradas = await servicio.listar(widget.raiz, ref);
      for (final entrada in entradas) {
        if (lineas.length > 200) break;
        final icono = entrada.esCarpeta ? '📁' : '📄';
        lineas.add('${'   ' * nivel}$icono ${entrada.nombre}');
        if (entrada.esCarpeta) {
          await recorrer(entrada.referencia, nivel + 1);
        }
      }
    }

    try {
      await recorrer(widget.referencia, 0);
    } catch (_) {
      lineas.add('No se pudo leer la estructura de esta carpeta.');
    }
    if (mounted) {
      setState(() {
        _lineas = lineas;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Estructura de la carpeta'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: SelectableText(
                  _lineas.isEmpty ? 'La carpeta está vacía.' : _lineas.join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
