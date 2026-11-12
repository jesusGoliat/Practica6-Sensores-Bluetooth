import 'package:comun/comun.dart';
import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/transferencia/estado_transferencias.dart';
import '../dominio/transferencia/cola_transferencias.dart';
import '../dominio/transferencia/estado_transferencia.dart';
import '../dominio/transferencia/registro_transferencia.dart';
import 'widgets/chip_estado.dart';
import 'widgets/dialogos_transferencia.dart';

/// Destino «Compartir» (Bluetooth): Enviar / Recibir / Historial.
class PantallaCompartir extends StatefulWidget {
  const PantallaCompartir({super.key});

  @override
  State<PantallaCompartir> createState() => _EstadoPantallaCompartir();
}

class _EstadoPantallaCompartir extends State<PantallaCompartir>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _refrescar();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refrescar());
  }

  void _refrescar() {
    if (!mounted || _tabs.index == 2) return;
    context.read<EstadoTransferencias>().refrescarEstadoBt(
        _tabs.index == 0 ? RolBle.central : RolBle.periferico);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TabBar(
        controller: _tabs,
        tabs: const [
          Tab(key: Key('tab-enviar'), icon: Icon(Icons.upload), text: 'Enviar'),
          Tab(key: Key('tab-recibir'), icon: Icon(Icons.download), text: 'Recibir'),
          Tab(key: Key('tab-historial'), icon: Icon(Icons.history), text: 'Historial'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: const [_TabEnviar(), _TabRecibir(), _TabHistorial()],
        ),
      ),
    ]);
  }
}

class _BannerBt extends StatelessWidget {
  const _BannerBt({required this.rol});
  final RolBle rol;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<EstadoTransferencias>();
    final e = t.estadoBt;
    if (e == EstadoBluetooth.encendido) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    final (icono, titulo) = switch (e) {
      EstadoBluetooth.apagado => (Icons.bluetooth_disabled, 'Bluetooth apagado'),
      EstadoBluetooth.sinPermiso => (Icons.lock_outline, 'Falta el permiso de Bluetooth'),
      EstadoBluetooth.permisoDenegadoPermanente => (Icons.block, 'Permiso denegado'),
      EstadoBluetooth.noSoportado => (Icons.bluetooth_disabled, 'Bluetooth no compatible'),
      _ => (Icons.help_outline, 'Estado de Bluetooth desconocido'),
    };
    final Widget? boton = switch (e) {
      EstadoBluetooth.sinPermiso => FilledButton(
          key: const Key('btn-bt-permiso'),
          onPressed: () => t.solicitarPermisos(rol),
          child: const Text('Conceder permiso')),
      EstadoBluetooth.permisoDenegadoPermanente => FilledButton.icon(
          key: const Key('btn-bt-ajustes'),
          onPressed: () => t.abrirAjustesSistema(rol),
          icon: const Icon(Icons.settings),
          label: const Text('Abrir ajustes de la app')),
      EstadoBluetooth.apagado || EstadoBluetooth.desconocido => OutlinedButton(
          key: const Key('btn-bt-reintentar'),
          onPressed: () => t.refrescarEstadoBt(rol),
          child: const Text('Volver a comprobar')),
      _ => null,
    };
    return MaterialBanner(
      key: const Key('banner-bt'),
      backgroundColor: esquema.errorContainer,
      leading: Icon(icono, color: esquema.onErrorContainer),
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo,
            style: TextStyle(fontWeight: FontWeight.bold, color: esquema.onErrorContainer)),
        Text(e.mensaje, style: TextStyle(color: esquema.onErrorContainer)),
      ]),
      actions: [if (boton != null) boton else const SizedBox.shrink()],
    );
  }
}

class TarjetaProgreso extends StatelessWidget {
  const TarjetaProgreso({super.key, required this.registro, required this.alCancelar});
  final RegistroTransferencia registro;
  final VoidCallback alCancelar;

  @override
  Widget build(BuildContext context) {
    final pct = (registro.progreso * 100).round();
    final enviado = registro.direccion == DireccionTransferencia.enviado;
    return Card(
      key: const Key('tarjeta-progreso'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(enviado ? Icons.upload_file : Icons.download),
            const SizedBox(width: 8),
            Expanded(
                child: Text(registro.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall)),
            ChipEstado(registro.estado),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              key: const Key('barra-progreso'),
              value: registro.progreso,
              minHeight: 8,
              semanticsLabel: 'Progreso $pct por ciento'),
          const SizedBox(height: 4),
          Text('$pct % · ${Formato.bytes(registro.bytesTransferidos)} de ${Formato.bytes(registro.longitud)}'),
          if (registro.dispositivo != null)
            Text(enviado ? 'Para ${registro.dispositivo}' : 'De ${registro.dispositivo}',
                style: Theme.of(context).textTheme.bodySmall),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('btn-cancelar-transferencia'),
              onPressed: alCancelar,
              icon: const Icon(Icons.close),
              label: const Text('Cancelar'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NotaPolitica extends StatelessWidget {
  const _NotaPolitica();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(EstadoTransferencias.textoPolitica,
                  style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );
}

class _TabEnviar extends StatelessWidget {
  const _TabEnviar();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<EstadoTransferencias>();
    final activa = t.activa;
    final pendientes = t.pendientes;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _BannerBt(rol: RolBle.central),
        const Text('Para enviar un archivo, elígelo en el explorador (menú ⋮ → '
            '«Enviar por Bluetooth») y conéctate aquí con un teléfono que esté en «Recibir».'),
        const _NotaPolitica(),
        if (t.emisorConectado)
          Card(
            child: ListTile(
              leading: const Icon(Icons.bluetooth_connected),
              title: Text('Conectado con ${t.dispositivoConectado!.nombre}'),
              trailing: TextButton(
                  key: const Key('btn-desconectar'),
                  onPressed: t.detenerEmisor,
                  child: const Text('Desconectar')),
            ),
          )
        else
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('btn-buscar'),
                onPressed: t.escaneando || t.conectando ? null : t.escanear,
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(t.escaneando ? 'Buscando…' : 'Buscar dispositivos'),
              ),
            ),
            if (t.escaneando)
              IconButton(
                  tooltip: 'Detener búsqueda',
                  onPressed: t.detenerEscaneo,
                  icon: const Icon(Icons.stop_circle_outlined)),
          ]),
        if (t.escaneando || t.conectando) const Padding(
            padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        if (!t.emisorConectado) ...[
          if (t.mensajeEscaneo != null && t.dispositivos.isEmpty && !t.escaneando)
            Padding(padding: const EdgeInsets.all(8), child: Text(t.mensajeEscaneo!)),
          for (final d in t.dispositivos)
            Card(
              child: ListTile(
                key: Key('dispositivo-${d.id}'),
                leading: const Icon(Icons.phone_android),
                title: Text(d.nombre.isEmpty ? 'Dispositivo sin nombre' : d.nombre),
                subtitle: Text('Señal ${d.rssi} dBm'),
                onTap: () async {
                  final ok = await t.conectarCon(d);
                  if (ok && context.mounted && t.pendientes.isNotEmpty) {
                    await confirmarEnvio(context, t);
                  }
                },
              ),
            ),
        ],
        const SizedBox(height: 8),
        if (activa != null && activa.direccion == DireccionTransferencia.enviado)
          TarjetaProgreso(registro: activa, alCancelar: t.cancelarActiva),
        Text('Cola (${pendientes.length}/${ColaTransferencias.maxPendientesPredeterminado})',
            key: const Key('titulo-cola'), style: Theme.of(context).textTheme.titleSmall),
        if (pendientes.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Sin envíos pendientes.')),
        for (final r in pendientes)
          ListTile(
            key: Key('cola-${r.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(r.nombre, overflow: TextOverflow.ellipsis),
            subtitle: Text(Formato.bytes(r.longitud)),
            trailing: IconButton(
                tooltip: 'Quitar de la cola',
                onPressed: () => t.cancelarPendiente(r.id),
                icon: const Icon(Icons.close)),
          ),
        if (t.emisorConectado && pendientes.isNotEmpty && activa == null)
          FilledButton.icon(
            key: const Key('btn-enviar-cola'),
            onPressed: () => confirmarEnvio(context, t),
            icon: const Icon(Icons.send),
            label: Text('Enviar ${pendientes.length} pendiente(s)'),
          ),
      ],
    );
  }
}

class _TabRecibir extends StatelessWidget {
  const _TabRecibir();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<EstadoTransferencias>();
    final activa = t.activa;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _BannerBt(rol: RolBle.periferico),
        const Text('Al activar «Recibir archivos» este teléfono se anuncia por Bluetooth. '
            'Cada archivo entrante te pedirá confirmación antes de guardarse en recibidos/.'),
        const _NotaPolitica(),
        SwitchListTile(
          key: const Key('switch-recibir'),
          title: const Text('Recibir archivos'),
          subtitle: Text(t.recibiendo
              ? (t.receptorConectado
                  ? 'Conectado con un emisor'
                  : 'Anunciando como ${t.nombreAnuncio ?? '…'}')
              : 'Desactivado'),
          value: t.recibiendo,
          onChanged: (v) => v ? t.iniciarRecepcion() : t.detenerRecepcion(),
        ),
        if (activa != null && activa.direccion == DireccionTransferencia.recibido)
          TarjetaProgreso(registro: activa, alCancelar: t.cancelarActiva),
      ],
    );
  }
}

class _TabHistorial extends StatelessWidget {
  const _TabHistorial();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<EstadoTransferencias>();
    final lista = t.historial;
    if (lista.isEmpty) {
      return const EstadoVacio(
          icono: Icons.history,
          titulo: 'Sin transferencias',
          mensaje: 'Aquí verás los envíos y recepciones, con su estado.');
    }
    return ListView(
      key: const Key('lista-historial'),
      padding: const EdgeInsets.all(8),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
              onPressed: t.borrarHistorialFinalizado,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Borrar finalizados')),
        ),
        for (final r in lista)
          Card(
            child: ListTile(
              key: Key('hist-${r.id}'),
              leading: Icon(r.direccion == DireccionTransferencia.enviado
                  ? Icons.upload_file
                  : Icons.download),
              title: Text(r.nombre, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                r.direccion == DireccionTransferencia.enviado ? 'Enviado' : 'Recibido',
                if (r.dispositivo != null) r.dispositivo!,
                Formato.bytes(r.longitud),
                if (r.estado == EstadoTransferencia.enCurso)
                  '${(r.progreso * 100).round()} %',
                if (r.motivo != null) r.motivo!,
              ].join(' · ')),
              isThreeLine: r.motivo != null,
              trailing: ChipEstado(r.estado),
            ),
          ),
      ],
    );
  }
}
