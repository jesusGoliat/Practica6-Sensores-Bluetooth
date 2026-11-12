import 'package:comun/comun.dart';
import 'package:flutter/material.dart';

import '../../datos/transferencia/estado_transferencias.dart';
import '../../dominio/transferencia/registro_transferencia.dart';

/// Confirmación explícita antes de enviar: «Enviar ARCHIVO (TAMAÑO) a DISPOSITIVO?».
Future<bool> confirmarEnvio(BuildContext context, EstadoTransferencias t) async {
  final lista = t.pendientes;
  final destino = t.dispositivoConectado?.nombre;
  if (lista.isEmpty || destino == null) return false;
  final RegistroTransferencia primero = lista.first;
  final extra = lista.length > 1 ? ' y ${lista.length - 1} más' : '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const Key('dialogo-confirmar-envio'),
      title: const Text('Enviar por Bluetooth'),
      content: Text('¿Enviar ${primero.nombre} (${Formato.bytes(primero.longitud)})$extra a $destino?\n\n'
          '${EstadoTransferencias.textoPolitica}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('btn-confirmar-envio'),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Enviar'),
        ),
      ],
    ),
  );
  if (ok == true) {
    t.iniciarCola();
    return true;
  }
  return false;
}

/// Diálogo de oferta entrante: nunca se acepta de forma implícita. Se cierra
/// solo cuando [EstadoTransferencias.ofertaEntrante] deja de existir.
Widget dialogoOferta(EstadoTransferencias t, OfertaEntrante o) {
  return PopScope(
    canPop: false,
    child: AlertDialog(
      key: const Key('dialogo-oferta'),
      title: const Text('Archivo entrante'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${o.emisor} quiere enviarte:'),
          const SizedBox(height: 8),
          Text(o.meta.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Tipo: ${o.meta.tipo} · ${Formato.bytes(o.meta.longitud)}'),
          const SizedBox(height: 8),
          const Text('Se guardará en recibidos/ solo si la integridad (SHA-256) coincide.'),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('btn-rechazar-oferta'),
          onPressed: () => t.responderOferta(false),
          child: const Text('Rechazar'),
        ),
        FilledButton(
          key: const Key('btn-aceptar-oferta'),
          onPressed: () => t.responderOferta(true),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}
