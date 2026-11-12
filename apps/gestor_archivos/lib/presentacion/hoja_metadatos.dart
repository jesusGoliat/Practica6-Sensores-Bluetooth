import 'package:comun/comun.dart';
import 'package:flutter/material.dart';

import '../dominio/modelos.dart';

/// Hoja inferior con los metadatos disponibles de un archivo o carpeta.
Future<void> mostrarMetadatos(BuildContext context, EntradaArchivo entrada) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (contexto) {
      final tipo = MapaTipos.tipoDe(entrada.nombre);
      return SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                T.metadatos,
                style: Theme.of(contexto).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (entrada.soloLectura)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Chip(
                    avatar: const Icon(Icons.lock_outline, size: 18),
                    label: const Text(T.soloLectura),
                  ),
                ),
              FilaMetadato(etiqueta: T.nombre, valor: entrada.nombre, icono: Icons.label_outline),
              FilaMetadato(
                etiqueta: T.tamano,
                valor: entrada.esCarpeta ? 'Carpeta' : Formato.bytes(entrada.tamano),
                icono: Icons.data_usage,
              ),
              FilaMetadato(
                etiqueta: T.modificado,
                valor: Formato.fecha(entrada.modificado),
                icono: Icons.schedule,
              ),
              FilaMetadato(
                etiqueta: T.creado,
                valor: Formato.fecha(entrada.creado),
                icono: Icons.event_outlined,
              ),
              FilaMetadato(
                etiqueta: T.tipoMime,
                valor: entrada.mime ?? tipo.mime,
                icono: Icons.category_outlined,
              ),
              FilaMetadato(
                etiqueta: T.tipoUt,
                valor: (entrada.utType ?? tipo.utType).isEmpty
                    ? T.noDisponible
                    : (entrada.utType ?? tipo.utType),
                icono: Icons.extension_outlined,
              ),
              FilaMetadato(
                etiqueta: T.ruta,
                valor: entrada.referencia,
                icono: Icons.route_outlined,
              ),
              FilaMetadato(
                etiqueta: T.origen,
                valor: entrada.origen.etiqueta,
                icono: Icons.storage_outlined,
              ),
            ],
          ),
        ),
      );
    },
  );
}
