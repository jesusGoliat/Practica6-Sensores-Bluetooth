/// Pantalla de la consulta web (único widget público de la UI).
library;

import 'dart:io';

import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../cliente/cliente_consulta.dart';
import '../dominio/almacen.dart';
import '../dominio/lista_blanca.dart';
import '../estado/estado_consulta_web.dart';
import '../estado/puente_ble.dart';

/// Pantalla completa de la consulta web por Bluetooth.
///
/// Sin parámetros usa BLE real y guarda caché y favoritos con `path_provider`.
/// La app solo debe declarar los permisos Bluetooth (ver `enlace_ble`).
class PantallaConsultaWeb extends StatefulWidget {
  /// [estado] permite inyectar un controlador propio (la pantalla no lo libera);
  /// [puente] y [almacen] se usan solo si la pantalla crea el suyo.
  const PantallaConsultaWeb({
    super.key,
    this.estado,
    this.puente,
    this.almacen,
    this.mostrarAppBar = true,
  });

  final EstadoConsultaWeb? estado;
  final PuenteBle? puente;
  final AlmacenTexto? almacen;

  /// Si es `false`, la pantalla no dibuja barra superior (la app ya tiene una).
  final bool mostrarAppBar;

  @override
  State<PantallaConsultaWeb> createState() => _PantallaConsultaWebState();
}

class _PantallaConsultaWebState extends State<PantallaConsultaWeb> {
  late final EstadoConsultaWeb _estado;
  late final bool _propio;

  @override
  void initState() {
    super.initState();
    _propio = widget.estado == null;
    _estado = widget.estado ??
        EstadoConsultaWeb(
          puente: widget.puente,
          almacen: widget.almacen ??
              AlmacenArchivos(() async => Directory(
                  '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}consulta_web')),
        );
  }

  @override
  void dispose() {
    if (_propio) _estado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EstadoConsultaWeb>.value(
      value: _estado,
      child: Consumer<EstadoConsultaWeb>(
        builder: (context, e, _) => Scaffold(
          appBar: widget.mostrarAppBar
              ? AppBar(
                  title: const Text('Consulta web por Bluetooth'),
                  actions: [
                    if (e.rol != RolConsulta.ninguno)
                      IconButton(
                        tooltip: 'Cambiar de rol',
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: e.cambiarRol,
                      ),
                  ],
                )
              : null,
          body: SafeArea(
            child: switch (e.rol) {
              RolConsulta.ninguno => const _SelectorRol(),
              RolConsulta.servidor => const _VistaServidor(),
              RolConsulta.cliente => const _VistaCliente(),
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- selector

class _SelectorRol extends StatelessWidget {
  const _SelectorRol();

  @override
  Widget build(BuildContext context) {
    final e = context.read<EstadoConsultaWeb>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Elige el rol de este dispositivo',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _TarjetaRol(
          clave: const Key('rol-servidor'),
          icono: Icons.public,
          titulo: 'Servidor (A)',
          texto: 'A: tiene Internet y hace las peticiones HTTPS.',
          onTap: () => e.elegirRol(RolConsulta.servidor),
        ),
        const SizedBox(height: 12),
        _TarjetaRol(
          clave: const Key('rol-cliente'),
          icono: Icons.bluetooth_searching,
          titulo: 'Cliente (B)',
          texto: 'B: sin Wi‑Fi ni datos, solo Bluetooth.',
          onTap: () => e.elegirRol(RolConsulta.cliente),
        ),
      ],
    );
  }
}

class _TarjetaRol extends StatelessWidget {
  const _TarjetaRol({
    required this.clave,
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.onTap,
  });
  final Key clave;
  final IconData icono;
  final String titulo;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      button: true,
      label: '$titulo. $texto',
      excludeSemantics: true,
      onTap: onTap,
      child: Card(
        key: clave,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(icono, size: 36, color: t.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: t.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(texto, style: t.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ piezas comunes

String _textoFase(EstadoConsultaWeb e) => switch (e.fase) {
      FaseConsulta.sinRol => 'Sin rol',
      FaseConsulta.iniciando => 'Iniciando…',
      FaseConsulta.bluetoothNoDisponible => 'Bluetooth no disponible',
      FaseConsulta.anunciando => 'Esperando a un cliente',
      FaseConsulta.buscando => 'Buscando servidores…',
      FaseConsulta.listaDispositivos => 'Elige un servidor',
      FaseConsulta.conectando => 'Conectando…',
      FaseConsulta.conectado => 'Conectado',
      FaseConsulta.desconectado => 'Desconectado',
    };

class _CintaEstado extends StatelessWidget {
  const _CintaEstado();

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EstadoConsultaWeb>();
    final rol = e.rol == RolConsulta.servidor ? 'Rol: Servidor (A)' : 'Rol: Cliente (B)';
    return Wrap(spacing: 8, runSpacing: 4, children: [
      Chip(avatar: const Icon(Icons.badge_outlined, size: 18), label: Text(rol)),
      Chip(
        key: const Key('chip-estado'),
        avatar: Icon(
            e.fase == FaseConsulta.conectado ? Icons.bluetooth_connected : Icons.bluetooth,
            size: 18),
        label: Text('Estado: ${_textoFase(e)}'),
      ),
    ]);
  }
}

class _AvisoBluetooth extends StatelessWidget {
  const _AvisoBluetooth();

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EstadoConsultaWeb>();
    final esq = Theme.of(context).colorScheme;
    final hayMensaje = e.mensaje != null;
    if (!hayMensaje) return const SizedBox.shrink();
    final problema = e.fase == FaseConsulta.bluetoothNoDisponible;
    return Card(
      color: problema ? esq.errorContainer : esq.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(problema ? Icons.bluetooth_disabled : Icons.info_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(e.mensaje!, key: const Key('mensaje-estado'))),
          ]),
          if (e.pidePermisoEnAjustes)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: e.abrirAjustes,
                icon: const Icon(Icons.settings),
                label: const Text('Abrir ajustes'),
              ),
            ),
          if (problema && !e.pidePermisoEnAjustes)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: e.reconectar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
        ]),
      ),
    );
  }
}

String _fechaCorta(DateTime f) => DateFormat('dd/MM HH:mm').format(f.toLocal());

// ---------------------------------------------------------------- servidor

class _VistaServidor extends StatelessWidget {
  const _VistaServidor();

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EstadoConsultaWeb>();
    final s = e.servidor!;
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _CintaEstado(),
        const _AvisoBluetooth(),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.devices_other),
          title: Text(e.fase == FaseConsulta.conectado
              ? 'Cliente conectado: ${e.nombreDispositivo ?? 'B'}'
              : 'Ningún cliente conectado'),
          subtitle: Text(e.fase == FaseConsulta.anunciando
              ? 'Anunciando como ${e.puente.nombreAnuncio}'
              : 'Este dispositivo necesita Internet para atender.'),
        ),
        if (e.fase == FaseConsulta.desconectado)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: e.reconectar,
              icon: const Icon(Icons.refresh),
              label: const Text('Volver a anunciar'),
            ),
          ),
        SwitchListTile(
          key: const Key('switch-retraso'),
          title: const Text('Retraso (diagnóstico)'),
          subtitle: const Text(
              'Añade 12 s antes de consultar para demostrar el timeout de 10 s (WEB-03).'),
          value: s.retrasoDiagnostico,
          onChanged: s.ponerRetraso,
        ),
        const Divider(),
        Text('Lista blanca', style: t.textTheme.titleMedium),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final d in ListaBlanca.contrato.dominios) Chip(label: Text(d)),
        ]),
        const SizedBox(height: 4),
        Text('Solo https, puerto 443, 10 peticiones/min, 256 KiB, 10 s.',
            style: t.textTheme.bodySmall),
        const Divider(),
        Text('Peticiones atendidas (${s.registro.length})', style: t.textTheme.titleMedium),
        if (s.registro.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Aún no hay peticiones.'),
          ),
        for (final r in s.registro)
          ListTile(
            dense: true,
            leading: Icon(r.resultado == 'ok' ? Icons.check_circle_outline : Icons.error_outline,
                color: r.resultado == 'ok' ? null : t.colorScheme.error),
            title: Text(r.url, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text('${r.req} · ${r.estado ?? '-'} · ${r.ms} ms · '
                '${r.resultado}${r.duplicada ? ' · duplicada (respuesta guardada)' : ''}'),
            trailing: Text(DateFormat('HH:mm:ss').format(r.fecha)),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------------- cliente

class _VistaCliente extends StatefulWidget {
  const _VistaCliente();

  @override
  State<_VistaCliente> createState() => _VistaClienteState();
}

class _VistaClienteState extends State<_VistaCliente> {
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _ir(EstadoConsultaWeb e) => e.consultar(_url.text);

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EstadoConsultaWeb>();
    final h = e.historial;
    final fav = e.favoritos.contiene(_url.text.trim());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _CintaEstado(),
        const _AvisoBluetooth(),
        _PanelConexion(e: e),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(
            tooltip: 'Atrás',
            onPressed: h.puedeAtras
                ? () async {
                    await e.atras();
                    if (h.actual != null) setState(() => _url.text = h.actual!);
                  }
                : null,
            icon: const Icon(Icons.arrow_back),
          ),
          IconButton(
            tooltip: 'Adelante',
            onPressed: h.puedeAdelante
                ? () async {
                    await e.adelante();
                    if (h.actual != null) setState(() => _url.text = h.actual!);
                  }
                : null,
            icon: const Icon(Icons.arrow_forward),
          ),
          IconButton(
            tooltip: fav ? 'Quitar de favoritos' : 'Agregar a favoritos',
            onPressed: _url.text.trim().isEmpty ? null : () => e.favoritos.alternar(_url.text.trim()),
            icon: Icon(fav ? Icons.star : Icons.star_border),
          ),
          PopupMenuButton<String>(
            tooltip: 'Favoritos y recursos de prueba',
            icon: const Icon(Icons.list),
            onSelected: (u) => setState(() => _url.text = u),
            itemBuilder: (_) => [
              for (final u in e.favoritos.urls)
                PopupMenuItem(value: u, child: Text('☆ $u', overflow: TextOverflow.ellipsis)),
              for (final r in ListaBlanca.contrato.recursos)
                PopupMenuItem(
                    value: r.url,
                    child: Text('${r.descripcion}\n${r.url}',
                        style: const TextStyle(fontSize: 13))),
            ],
          ),
          IconButton(
            tooltip: 'Formatos admitidos',
            onPressed: () => _dialogoFormatos(context),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: 'Caché (${e.cache.longitud})',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ChangeNotifierProvider<EstadoConsultaWeb>.value(
                value: e,
                child: const _PantallaCache(),
              ),
            )),
            icon: const Icon(Icons.storage_outlined),
          ),
        ]),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('barra-direccion'),
              controller: _url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _ir(e),
              decoration: const InputDecoration(
                labelText: 'Dirección (https)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56,
            child: FilledButton(
              key: const Key('boton-ir'),
              onPressed: e.consultando ? null : () => _ir(e),
              child: const Text('Ir'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (e.consultando) const LinearProgressIndicator(),
        if (e.resultado != null) _PanelResultado(r: e.resultado!),
      ],
    );
  }
}

class _PanelConexion extends StatelessWidget {
  const _PanelConexion({required this.e});
  final EstadoConsultaWeb e;

  @override
  Widget build(BuildContext context) {
    switch (e.fase) {
      case FaseConsulta.conectado:
        return ListTile(
          leading: const Icon(Icons.bluetooth_connected),
          title: Text('Conectado a ${e.nombreDispositivo ?? 'A'}'),
        );
      case FaseConsulta.buscando:
      case FaseConsulta.iniciando:
      case FaseConsulta.conectando:
        return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
      case FaseConsulta.bluetoothNoDisponible:
        return const SizedBox.shrink();
      case FaseConsulta.desconectado:
      case FaseConsulta.listaDispositivos:
      case FaseConsulta.anunciando:
      case FaseConsulta.sinRol:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                e.fase == FaseConsulta.desconectado
                    ? 'Sin conexión con A. Puedes ver copias de la caché.'
                    : 'Servidores A encontrados',
              ),
              for (final d in e.dispositivos)
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(d.nombre.isEmpty ? d.id : d.nombre),
                  subtitle: Text('${d.rssi} dBm'),
                  onTap: () => e.conectar(d),
                ),
              Wrap(spacing: 8, children: [
                if (e.ultimoDispositivo != null)
                  FilledButton.icon(
                    key: const Key('boton-reconectar'),
                    onPressed: e.reconectar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reconectar'),
                  ),
                OutlinedButton.icon(
                  onPressed: e.buscar,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar servidores'),
                ),
              ]),
            ]),
          ),
        );
    }
  }
}

class _PanelResultado extends StatelessWidget {
  const _PanelResultado({required this.r});
  final Resultado r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final oscuro = t.brightness == Brightness.dark;
    final children = <Widget>[];
    if (r.origen != null) {
      final red = r.origen == OrigenRespuesta.red;
      final texto = red ? 'RED' : 'CACHÉ · ${_fechaCorta(r.fecha!)}';
      final fondo = red
          ? (oscuro ? const Color(0xFF1B5E20) : const Color(0xFFC8E6C9))
          : (oscuro ? const Color(0xFF8A5A00) : const Color(0xFFFFE0B2));
      final fg = oscuro ? Colors.white : Colors.black87;
      children.add(Semantics(
        label: red ? 'Respuesta recibida por la red' : 'Copia de caché del $texto',
        child: Chip(
          key: const Key('insignia-origen'),
          avatar: Icon(red ? Icons.cloud_done : Icons.history, size: 18, color: fg),
          backgroundColor: fondo,
          label: Text(texto, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
        ),
      ));
      children.add(Wrap(spacing: 16, runSpacing: 4, children: [
        Text('Estado: ${r.estado}', key: const Key('texto-estado-http')),
        Text('Tiempo: ${r.ms ?? '-'} ms'),
        Text('Tamaño: ${r.tamano ?? '-'} B'),
        Text('Tipo: ${r.tipo}'),
      ]));
      if (r.aviso != null) {
        children.add(Text(r.aviso!, style: TextStyle(color: t.colorScheme.error)));
      }
      children.add(const Divider());
      children.add(_Visor(r: r));
    } else {
      children.add(Card(
        color: t.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.error_outline, color: t.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(r.error ?? 'Error', key: const Key('texto-error'),
                  style: TextStyle(color: t.colorScheme.onErrorContainer)),
            ),
          ]),
        ),
      ));
      if (r.codigoError != null) {
        children.add(Text('Código: ${r.codigoError}', style: t.textTheme.bodySmall));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 8), child: c)],
    );
  }
}

class _Visor extends StatelessWidget {
  const _Visor({required this.r});
  final Resultado r;

  @override
  Widget build(BuildContext context) {
    final tipo = r.tipo ?? '';
    if (r.bytes != null && tipo.startsWith('image/')) {
      return Semantics(
        label: 'Imagen recibida',
        image: true,
        child: Center(
          child: Image.memory(r.bytes!, errorBuilder: (_, _, _) => const Text('No se pudo decodificar la imagen.')),
        ),
      );
    }
    final texto = r.texto ?? '';
    if (tipo == 'application/json') {
      return SizedBox(
        height: 380,
        child: VisorCodigo(nombre: 'respuesta.json', contenido: texto),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (tipo == 'text/html')
        const Text('HTML mostrado como texto; nunca se ejecuta.'),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(texto,
            key: const Key('texto-respuesta'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
      ),
    ]);
  }
}

void _dialogoFormatos(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Formatos admitidos'),
      content: const SingleChildScrollView(
        child: Text('• text/plain: texto.\n'
            '• application/json: se muestra con formato y colores.\n'
            '• text/html: se muestra como texto, no se ejecuta.\n'
            '• image/jpeg e image/png: hasta 64 KiB.\n\n'
            'Otro tipo: «formato no admitido». Respuesta máxima: 256 KiB '
            '(en la práctica ~64 KB por el límite del mensaje Bluetooth).\n'
            'Solo https, dominios de la lista blanca, 10 peticiones por minuto.'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    ),
  );
}

// ------------------------------------------------------------------- caché

class _PantallaCache extends StatelessWidget {
  const _PantallaCache();

  @override
  Widget build(BuildContext context) {
    final e = context.watch<EstadoConsultaWeb>();
    final lista = e.cache.entradas;
    return Scaffold(
      appBar: AppBar(
        title: Text('Caché (${lista.length}/${e.cache.capacidad})'),
        actions: [
          IconButton(
            tooltip: 'Vaciar caché',
            onPressed: lista.isEmpty ? null : e.cache.vaciar,
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: lista.isEmpty
          ? const EstadoVacio(
              icono: Icons.storage_outlined,
              titulo: 'Caché vacía',
              mensaje: 'Las respuestas recibidas por la red se guardan aquí con su fecha.',
            )
          : ListView(children: [
              for (final c in lista)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(c.url, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('CACHÉ · ${_fechaCorta(c.fecha)} · ${c.tipo} · ${c.tamano} B'),
                  onTap: () {
                    e.abrirDeCache(c);
                    Navigator.of(context).pop();
                  },
                  trailing: IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => e.cache.eliminar(c.url),
                  ),
                ),
            ]),
    );
  }
}
