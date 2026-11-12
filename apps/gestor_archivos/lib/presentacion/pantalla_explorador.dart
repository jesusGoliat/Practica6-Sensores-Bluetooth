import 'dart:typed_data';

import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/acciones_archivo.dart';
import '../datos/estado_gestor.dart';
import '../dominio/error_archivo.dart';
import '../dominio/modelos.dart';
import 'arbol_carpetas.dart';
import 'dialogo_no_soportado.dart';
import 'hoja_metadatos.dart';
import 'pantalla_visor.dart';
import 'widgets/dialogo_tema.dart';

class PantallaExplorador extends StatelessWidget {
  const PantallaExplorador({super.key});

  @override
  Widget build(BuildContext context) {
    final gestor = context.watch<EstadoGestor>();
    final raiz = gestor.raizActual;
    if (raiz == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _SelectorRaices(gestor: gestor),
        Breadcrumbs(
          key: const Key('breadcrumbs'),
          prefijo: IconButton(
            key: const Key('btn-subir'),
            tooltip: T.volver,
            onPressed: gestor.pila.isEmpty ? null : () => gestor.subir(),
            icon: const Icon(Icons.arrow_upward),
          ),
          migajas: <Migaja>[
            Migaja(
              raiz.nombre,
              icono: Icons.home_outlined,
              alTocar: gestor.pila.isEmpty ? null : () => gestor.irA(-1),
            ),
            for (var i = 0; i < gestor.pila.length; i++)
              Migaja(
                gestor.pila[i].nombre,
                alTocar: i == gestor.pila.length - 1 ? null : () => gestor.irA(i),
              ),
          ],
        ),
        _BarraHerramientas(gestor: gestor),
        if (gestor.cargando) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: gestor.entradas.isEmpty && !gestor.cargando
              ? EstadoVacio(
                  icono: Icons.folder_open_outlined,
                  titulo: T.vacio,
                  mensaje: raiz.origen == OrigenArchivo.privado
                      ? 'Usa el botón de nueva carpeta o importa un archivo para empezar.'
                      : 'Esta carpeta autorizada no tiene elementos visibles.',
                  accion: FilledButton.icon(
                    onPressed: () => _nuevaCarpeta(context, gestor),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text(T.nuevaCarpeta),
                  ),
                )
              : gestor.cuadricula
                  ? _Cuadricula(gestor: gestor)
                  : _Lista(gestor: gestor),
        ),
        if (gestor.portapapeles != null)
          _BarraPortapapeles(gestor: gestor, alPegar: () => _pegar(context, gestor)),
      ],
    );
  }
}

class _SelectorRaices extends StatelessWidget {
  const _SelectorRaices({required this.gestor});

  final EstadoGestor gestor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          for (final raiz in gestor.raices)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('raiz-${raiz.id}'),
                avatar: Icon(
                  raiz.origen == OrigenArchivo.privado
                      ? Icons.phone_android
                      : Icons.folder_shared_outlined,
                  size: 18,
                ),
                label: Text(
                  raiz.nombre,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: gestor.raizActual?.id == raiz.id,
                onSelected: (_) async {
                  try {
                    await gestor.abrirRaiz(raiz);
                  } catch (e) {
                    if (context.mounted) avisarError(context, e);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _BarraHerramientas extends StatelessWidget {
  const _BarraHerramientas({required this.gestor});

  final EstadoGestor gestor;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            key: const Key('btn-nueva-carpeta'),
            tooltip: T.nuevaCarpeta,
            onPressed: () => _nuevaCarpeta(context, gestor),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            key: const Key('btn-recargar'),
            tooltip: 'Recargar',
            onPressed: gestor.recargar,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            key: const Key('btn-arbol'),
            tooltip: 'Ver estructura',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ArbolCarpetas(
                raiz: gestor.raizActual!,
                referencia: gestor.referenciaActual,
              ),
            ),
            icon: const Icon(Icons.account_tree_outlined),
          ),
          IconButton(
            key: const Key('btn-vista'),
            tooltip: gestor.cuadricula ? 'Ver lista' : 'Ver cuadrícula',
            onPressed: () => gestor.cambiarVista(!gestor.cuadricula),
            icon: Icon(gestor.cuadricula ? Icons.view_list : Icons.grid_view),
          ),
          PopupMenuButton<String>(
            key: const Key('btn-orden'),
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort),
            onSelected: gestor.cambiarOrden,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'nombre', child: Text('Nombre')),
              PopupMenuItem(value: 'fecha', child: Text('Fecha (más reciente)')),
              PopupMenuItem(value: 'tamano', child: Text('Tamaño (mayor)')),
            ],
          ),
          if (gestor.portapapeles != null)
            TextButton.icon(
              key: const Key('btn-pegar'),
              onPressed: () => _pegar(context, gestor),
              icon: const Icon(Icons.content_paste),
              label: Text('${T.pegarAqui} (${gestor.portapapeles!.entrada.nombre})'),
            ),
        ],
      ),
    );
  }
}

class _BarraPortapapeles extends StatelessWidget {
  const _BarraPortapapeles({required this.gestor, required this.alPegar});

  final EstadoGestor gestor;
  final VoidCallback alPegar;

  @override
  Widget build(BuildContext context) {
    final portado = gestor.portapapeles!;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        dense: true,
        leading: Icon(portado.modo == ModoPortapapeles.copiar ? Icons.copy : Icons.drive_file_move),
        title: Text(
          '${portado.modo == ModoPortapapeles.copiar ? T.copiar : T.mover}: ${portado.entrada.nombre}',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(onPressed: alPegar, child: const Text(T.pegarAqui)),
            IconButton(
              tooltip: T.cancelar,
              onPressed: gestor.cancelarPortapapeles,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.gestor});

  final EstadoGestor gestor;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
      itemCount: gestor.entradas.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _FilaArchivo(entrada: gestor.entradas[i], gestor: gestor),
    );
  }
}

class _Cuadricula extends StatelessWidget {
  const _Cuadricula({required this.gestor});

  final EstadoGestor gestor;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: 0.86,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: gestor.entradas.length,
      itemBuilder: (context, i) => _TarjetaArchivo(entrada: gestor.entradas[i], gestor: gestor),
    );
  }
}

class _FilaArchivo extends StatelessWidget {
  const _FilaArchivo({required this.entrada, required this.gestor});

  final EntradaArchivo entrada;
  final EstadoGestor gestor;

  @override
  Widget build(BuildContext context) {
    final favorito = gestor.esFavorito(entrada);
    return ListTile(
      key: Key('entrada-${entrada.nombre}'),
      leading: _Miniatura(entrada: entrada, gestor: gestor, tamano: 46),
      title: Text(entrada.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitulo(entrada)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entrada.soloLectura) const Icon(Icons.lock_outline, size: 18),
          IconButton(
            tooltip: T.favoritos,
            onPressed: () => gestor.alternarFavorito(entrada),
            icon: Icon(favorito ? Icons.star : Icons.star_border),
          ),
          _BotonMenu(entrada: entrada, gestor: gestor),
        ],
      ),
      onTap: () => _alTocar(context, gestor, entrada),
      onLongPress: () => _mostrarAcciones(context, gestor, entrada),
    );
  }
}

class _TarjetaArchivo extends StatelessWidget {
  const _TarjetaArchivo({required this.entrada, required this.gestor});

  final EntradaArchivo entrada;
  final EstadoGestor gestor;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Card(
      key: Key('tarjeta-${entrada.nombre}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _alTocar(context, gestor, entrada),
        onLongPress: () => _mostrarAcciones(context, gestor, entrada),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: _Miniatura(entrada: entrada, gestor: gestor, tamano: 84, grande: true),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                entrada.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                _subtitulo(entrada),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({
    required this.entrada,
    required this.gestor,
    required this.tamano,
    this.grande = false,
  });

  final EntradaArchivo entrada;
  final EstadoGestor gestor;
  final double tamano;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final tipo = MapaTipos.tipoDe(entrada.nombre);
    final icono = entrada.esCarpeta
        ? Icons.folder
        : tipo.esJson
            ? Icons.data_object
            : tipo.esXml
                ? Icons.code
                : tipo.esImagen
                    ? Icons.image_outlined
                    : tipo.esMarkdown
                        ? Icons.article_outlined
                        : Icons.description_outlined;
    final color = entrada.esCarpeta
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    if (!tipo.esImagen) {
      return Icon(icono, size: tamano, color: color);
    }
    return SizedBox(
      width: tamano,
      height: tamano,
      child: FutureBuilder<Uint8List?>(
        future: gestor.miniatura(entrada),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                cacheWidth: 320,
                errorBuilder: (_, _, _) => Icon(icono, size: tamano, color: color),
              ),
            );
          }
          return Icon(icono, size: tamano, color: color);
        },
      ),
    );
  }
}

class _BotonMenu extends StatelessWidget {
  const _BotonMenu({required this.entrada, required this.gestor});

  final EntradaArchivo entrada;
  final EstadoGestor gestor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: Key('menu-${entrada.nombre}'),
      tooltip: 'Acciones',
      onSelected: (accion) => _ejecutarAccion(context, gestor, entrada, accion),
      itemBuilder: (_) => _items(entrada),
    );
  }
}

List<PopupMenuEntry<String>> _items(EntradaArchivo entrada) {
  return <PopupMenuEntry<String>>[
    const PopupMenuItem(value: 'abrir', child: Text(T.abrir)),
    const PopupMenuItem(value: 'metadatos', child: Text(T.metadatos)),
    const PopupMenuItem(value: 'favorito', child: Text(T.favoritos)),
    const PopupMenuDivider(),
    const PopupMenuItem(value: 'renombrar', child: Text(T.renombrar)),
    const PopupMenuItem(value: 'copiar', child: Text(T.copiar)),
    const PopupMenuItem(value: 'mover', child: Text(T.mover)),
    const PopupMenuItem(value: 'compartir', child: Text(T.compartir)),
    const PopupMenuItem(value: 'exportar', child: Text(T.exportar)),
    if (!entrada.esCarpeta) const PopupMenuItem(value: 'abrirCon', child: Text(T.abrirCon)),
    const PopupMenuDivider(),
    const PopupMenuItem(value: 'eliminar', child: Text(T.eliminar)),
  ];
}

String _subtitulo(EntradaArchivo entrada) {
  if (entrada.esCarpeta) return 'Carpeta';
  final fecha = entrada.modificado == null ? '' : ' · ${Formato.fecha(entrada.modificado)}';
  return '${Formato.bytes(entrada.tamano)}$fecha';
}

Future<void> _alTocar(BuildContext context, EstadoGestor gestor, EntradaArchivo entrada) async {
  if (entrada.esCarpeta) {
    try {
      await gestor.abrirCarpeta(entrada);
    } catch (e) {
      if (context.mounted) avisarError(context, e);
    }
    return;
  }
  await _abrirArchivo(context, gestor, entrada);
}

Future<void> _abrirArchivo(BuildContext context, EstadoGestor gestor, EntradaArchivo entrada) async {
  final tipo = MapaTipos.tipoDe(entrada.nombre);
  if (!tipo.tieneVisor) {
    await _dialogoSinVisor(context, gestor, entrada);
    return;
  }
  try {
    final archivo = await gestor.abrirArchivo(entrada);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PantallaVisor(archivo: archivo)),
    );
  } catch (e) {
    if (context.mounted) avisarError(context, e);
  }
}

Future<void> _dialogoSinVisor(BuildContext context, EstadoGestor gestor, EntradaArchivo entrada) async {
  final accion = await mostrarDialogoNoSoportado(context, entrada);
  if (accion == null || !context.mounted) return;
  final acciones = context.read<AccionesArchivo>();
  final servicio = gestor.servicioDe(entrada);
  try {
    switch (accion) {
      case AccionNoSoportada.abrir:
        final aviso = await acciones.abrirCon(entrada, servicio);
        if (aviso != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
        }
        break;
      case AccionNoSoportada.compartir:
        await acciones.compartir(entrada, servicio);
        break;
      case AccionNoSoportada.exportar:
        final guardado = await acciones.exportar(entrada, servicio);
        if (guardado && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copia exportada correctamente.')),
          );
        }
        break;
    }
  } catch (e) {
    if (context.mounted) avisarError(context, e);
  }
}

Future<void> _mostrarAcciones(BuildContext context, EstadoGestor gestor, EntradaArchivo entrada) async {
  final accion = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (contexto) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(entrada.nombre),
            subtitle: Text(_subtitulo(entrada)),
          ),
          const Divider(height: 1),
          for (final item in _items(entrada))
            if (item is PopupMenuItem<String>)
              ListTile(
                leading: Icon(_iconoAccion(item.value ?? '')),
                title: Text((item.child as Text).data ?? ''),
                onTap: () => Navigator.pop(contexto, item.value),
              ),
        ],
      ),
    ),
  );
  if (accion != null && context.mounted) {
    await _ejecutarAccion(context, gestor, entrada, accion);
  }
}

IconData _iconoAccion(String accion) => switch (accion) {
      'abrir' => Icons.open_in_new,
      'metadatos' => Icons.info_outline,
      'favorito' => Icons.star_border,
      'renombrar' => Icons.drive_file_rename_outline,
      'copiar' => Icons.copy,
      'mover' => Icons.drive_file_move,
      'compartir' => Icons.share_outlined,
      'exportar' => Icons.save_alt,
      'abrirCon' => Icons.open_in_browser,
      _ => Icons.delete_outline,
    };

Future<void> _ejecutarAccion(
  BuildContext context,
  EstadoGestor gestor,
  EntradaArchivo entrada,
  String accion,
) async {
  switch (accion) {
    case 'abrir':
      await _alTocar(context, gestor, entrada);
      return;
    case 'metadatos':
      await mostrarMetadatos(context, entrada);
      return;
    case 'favorito':
      await gestor.alternarFavorito(entrada);
      return;
    case 'renombrar':
      await _renombrar(context, gestor, entrada);
      return;
    case 'copiar':
      gestor.marcarPortapapeles(entrada, ModoPortapapeles.copiar);
      _aviso(context, 'Copia lista. Abre la carpeta destino y pulsa «${T.pegarAqui}».');
      return;
    case 'mover':
      gestor.marcarPortapapeles(entrada, ModoPortapapeles.mover);
      _aviso(context, 'Elemento listo para mover. Abre la carpeta destino y pulsa «${T.pegarAqui}».');
      return;
    case 'compartir':
      try {
        await context.read<AccionesArchivo>().compartir(entrada, gestor.servicioDe(entrada));
      } catch (e) {
        if (context.mounted) avisarError(context, e);
      }
      return;
    case 'exportar':
      try {
        final guardado = await context.read<AccionesArchivo>().exportar(entrada, gestor.servicioDe(entrada));
        if (guardado && context.mounted) _aviso(context, 'Copia exportada correctamente.');
      } catch (e) {
        if (context.mounted) avisarError(context, e);
      }
      return;
    case 'abrirCon':
      try {
        final mensaje = await context.read<AccionesArchivo>().abrirCon(entrada, gestor.servicioDe(entrada));
        if (mensaje != null && context.mounted) _aviso(context, mensaje);
      } catch (e) {
        if (context.mounted) avisarError(context, e);
      }
      return;
    case 'eliminar':
      final confirmado = await confirmarAccion(
        context,
        titulo: '${T.eliminar} ${entrada.nombre}',
        mensaje: entrada.esCarpeta
            ? 'Se eliminará la carpeta y todo su contenido. Esta acción no se puede deshacer.'
            : 'El archivo se eliminará de forma permanente. Esta acción no se puede deshacer.',
        textoConfirmar: T.eliminar,
        destructivo: true,
      );
      if (!confirmado) return;
      try {
        await gestor.eliminar(entrada);
      } catch (e) {
        if (context.mounted) avisarError(context, e);
      }
      return;
  }
}

Future<void> _renombrar(BuildContext context, EstadoGestor gestor, EntradaArchivo entrada) async {
  final controlador = TextEditingController(text: entrada.nombre);
  final nuevo = await showDialog<String>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text(T.renombrar),
      content: TextField(
        controller: controlador,
        autofocus: true,
        decoration: const InputDecoration(labelText: T.nombre),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(contexto), child: const Text(T.cancelar)),
        FilledButton(
          onPressed: () => Navigator.pop(contexto, controlador.text.trim()),
          child: const Text(T.renombrar),
        ),
      ],
    ),
  );
  controlador.dispose();
  if (nuevo == null || nuevo.isEmpty || nuevo == entrada.nombre || !context.mounted) return;
  try {
    await gestor.renombrar(entrada, nuevo);
  } on ErrorArchivo catch (e) {
    if (e.tipo == TipoErrorArchivo.conflicto && context.mounted) {
      final reemplazar = await confirmarAccion(
        context,
        titulo: 'Ya existe un elemento',
        mensaje: '¿Quieres reemplazar «$nuevo»?',
        textoConfirmar: 'Reemplazar',
        destructivo: true,
      );
      if (reemplazar) {
        try {
          await gestor.renombrar(entrada, nuevo, sobrescribir: true);
        } catch (e2) {
          if (context.mounted) avisarError(context, e2);
        }
      }
    } else if (context.mounted) {
      avisarError(context, e);
    }
  } catch (e) {
    if (context.mounted) avisarError(context, e);
  }
}

Future<void> _nuevaCarpeta(BuildContext context, EstadoGestor gestor) async {
  final controlador = TextEditingController();
  final nombre = await showDialog<String>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text(T.nuevaCarpeta),
      content: TextField(
        controller: controlador,
        autofocus: true,
        decoration: const InputDecoration(labelText: T.nombre),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(contexto), child: const Text(T.cancelar)),
        FilledButton(
          onPressed: () => Navigator.pop(contexto, controlador.text.trim()),
          child: const Text('Crear'),
        ),
      ],
    ),
  );
  controlador.dispose();
  if (nombre == null || nombre.isEmpty || !context.mounted) return;
  try {
    await gestor.crearCarpeta(nombre);
  } catch (e) {
    if (context.mounted) avisarError(context, e);
  }
}

Future<void> _pegar(BuildContext context, EstadoGestor gestor) async {
  try {
    await gestor.pegar();
    if (context.mounted) _aviso(context, 'Operación completada.');
  } on ErrorArchivo catch (e) {
    if (e.tipo == TipoErrorArchivo.conflicto && context.mounted) {
      final reemplazar = await confirmarAccion(
        context,
        titulo: 'Ya existe un elemento',
        mensaje: 'El destino ya contiene un elemento con ese nombre. ¿Quieres reemplazarlo?',
        textoConfirmar: 'Reemplazar',
        destructivo: true,
      );
      if (reemplazar && context.mounted) {
        try {
          await gestor.pegar(sobrescribir: true);
          if (context.mounted) _aviso(context, 'Operación completada.');
        } catch (e2) {
          if (context.mounted) avisarError(context, e2);
        }
      }
    } else if (context.mounted) {
      avisarError(context, e);
    }
  } catch (e) {
    if (context.mounted) avisarError(context, e);
  }
}

void _aviso(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
