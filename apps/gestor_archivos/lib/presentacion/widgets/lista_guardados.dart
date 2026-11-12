import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datos/acciones_archivo.dart';
import '../../datos/estado_gestor.dart';
import '../../dominio/modelos.dart';
import '../dialogo_no_soportado.dart';
import '../hoja_metadatos.dart';
import '../pantalla_visor.dart';
import 'dialogo_tema.dart';

/// Lista compartida por Favoritos y Recientes.
class ListaGuardados extends StatelessWidget {
  const ListaGuardados({
    super.key,
    required this.entradas,
    required this.alQuitar,
    required this.textoQuitar,
  });

  final List<EntradaArchivo> entradas;
  final Future<void> Function(EntradaArchivo) alQuitar;
  final String textoQuitar;

  @override
  Widget build(BuildContext context) {
    final gestor = context.read<EstadoGestor>();
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: entradas.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final entrada = entradas[i];
        final tipo = MapaTipos.tipoDe(entrada.nombre);
        return ListTile(
          key: Key('guardado-${entrada.clave}'),
          leading: Icon(
            entrada.esCarpeta
                ? Icons.folder
                : tipo.esImagen
                    ? Icons.image_outlined
                    : tipo.esJson
                        ? Icons.data_object
                        : Icons.description_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(entrada.nombre, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            entrada.disponible
                ? '${entrada.origen.etiqueta}${entrada.modificado == null ? '' : ' · ${Formato.fecha(entrada.modificado)}'}'
                : T.rutaNoDisponible,
            style: TextStyle(
              color: entrada.disponible ? null : Theme.of(context).colorScheme.error,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: T.metadatos,
                onPressed: entrada.disponible ? () => mostrarMetadatos(context, entrada) : null,
                icon: const Icon(Icons.info_outline),
              ),
              IconButton(
                key: Key('quitar-${entrada.clave}'),
                tooltip: textoQuitar,
                onPressed: () => alQuitar(entrada),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          onTap: () => _abrir(context, gestor, entrada),
        );
      },
    );
  }

  Future<void> _abrir(BuildContext context, EstadoGestor gestor, EntradaArchivo entrada) async {
    if (!entrada.disponible) {
      final quitar = await confirmarAccion(
        context,
        titulo: T.rutaNoDisponible,
        mensaje: 'El archivo o la carpeta se movió, se eliminó o ya no tenemos permiso. '
            'Puedes quitarlo de esta lista.',
        textoConfirmar: textoQuitar,
        destructivo: true,
      );
      if (quitar) await alQuitar(entrada);
      return;
    }
    try {
      if (entrada.esCarpeta) {
        await gestor.abrirCarpeta(entrada);
        return;
      }
      final tipo = MapaTipos.tipoDe(entrada.nombre);
      if (!tipo.tieneVisor) {
        final accion = await mostrarDialogoNoSoportado(context, entrada);
        if (accion == null || !context.mounted) return;
        final acciones = context.read<AccionesArchivo>();
        final servicio = gestor.servicioDe(entrada);
        if (accion == AccionNoSoportada.abrir) {
          final mensaje = await acciones.abrirCon(entrada, servicio);
          if (mensaje != null && context.mounted) avisarError(context, mensaje);
        } else if (accion == AccionNoSoportada.compartir) {
          await acciones.compartir(entrada, servicio);
        } else {
          await acciones.exportar(entrada, servicio);
        }
        return;
      }
      final archivo = await gestor.abrirArchivo(entrada);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PantallaVisor(archivo: archivo)),
      );
    } catch (e) {
      if (context.mounted) avisarError(context, e);
    }
  }
}
