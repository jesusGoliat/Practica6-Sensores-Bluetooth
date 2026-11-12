import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_juego.dart';
import '../datos/estado_partida_red.dart';
import '../dominio/partida_red.dart';
import 'widgets/alcance_movimiento.dart';
import 'widgets/tablero_cartas.dart';

/// Destino «Bluetooth»: elección de rol, búsqueda y tablero en red.
class PantallaBluetooth extends StatefulWidget {
  const PantallaBluetooth({super.key, this.visible = true});

  /// `false` cuando otra pestaña está activa (pausa el control por movimiento).
  final bool visible;

  @override
  State<PantallaBluetooth> createState() => _EstadoPantallaBluetooth();
}

class _EstadoPantallaBluetooth extends State<PantallaBluetooth> {
  late final EstadoPartidaRed _red;
  bool _dialogoSolicitud = false;
  bool _dialogoResultado = false;

  @override
  void initState() {
    super.initState();
    _red = context.read<EstadoPartidaRed>();
    _red.addListener(_alCambiar);
    _red.cargarPendiente();
  }

  @override
  void dispose() {
    _red.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    final aviso = _red.aviso;
    if (aviso != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(aviso)));
      });
      _red.limpiarAviso();
    }
    final sol = _red.solicitud;
    if (sol != null && !_dialogoSolicitud) {
      _dialogoSolicitud = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final acepta = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: Text('¿Aceptar a ${sol.nombre}?'),
            content: const Text('Esta persona quiere jugar contigo por Bluetooth.'),
            actions: [
              TextButton(
                key: const Key('btn-rechazar-invitado'),
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Rechazar'),
              ),
              FilledButton(
                key: const Key('btn-aceptar-invitado'),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
        _dialogoSolicitud = false;
        _red.responderSolicitud(acepta ?? false);
      });
    }
    final s = _red.sesion;
    if (s != null && s.finalizada && !_dialogoResultado) {
      _dialogoResultado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _mostrarResultado(s);
        _dialogoResultado = false;
        await _red.cerrarPartida();
      });
    }
  }

  Future<void> _mostrarResultado(SesionPartidaRed s) {
    String titulo;
    if (s.estado == EstadoSesionRed.abandonada) {
      titulo = _red.mensajeRival ?? 'El otro jugador salió';
    } else if (s.motivoFin == 'sesion') {
      titulo = 'La partida terminó';
    } else if (s.resultado == 'empate') {
      titulo = '¡Empate!';
    } else {
      titulo = s.resultado == s.rol.name ? '¡Ganaste!' : 'Ganó el rival';
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        key: const Key('dialogo-resultado-red'),
        title: Text(titulo),
        content: Text('Marcador final: tú ${s.puntosLocales} - rival ${s.puntosRival}.'),
        actions: [
          FilledButton(
            key: const Key('btn-resultado-aceptar'),
            onPressed: () => Navigator.pop(c),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final red = context.watch<EstadoPartidaRed>();
    if (red.sesion != null) return _VistaPartida(red: red, visible: widget.visible);
    return _VistaInicio(red: red);
  }
}

// ------------------------------------------------------------------ inicio

class _VistaInicio extends StatelessWidget {
  const _VistaInicio({required this.red});
  final EstadoPartidaRed red;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final nombre = context.read<EstadoJuego>().nombreJugador;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('Jugar por Bluetooth', style: texto.titleLarge),
        const SizedBox(height: 4),
        const Text('Dos dispositivos, mismo tablero. Los permisos se piden solo al elegir un rol.'),
        const SizedBox(height: 12),
        if (red.pendiente != null) _TarjetaPendiente(red: red),
        if (red.bt != null && !red.bt!.disponible || red.mensajeBt != null)
          _BannerBluetooth(red: red),
        if (red.fase == FaseRed.inicio) ...[
          _TarjetaRol(
            llave: const Key('rol-anfitrion'),
            icono: Icons.wifi_tethering,
            titulo: 'Anfitrión',
            descripcion: 'Crea la partida y espera a que alguien se una.',
            alTocar: () {
              red.nombreLocal = nombre;
              red.iniciarAnfitrion();
            },
          ),
          const SizedBox(height: 8),
          _TarjetaRol(
            llave: const Key('rol-invitado'),
            icono: Icons.search,
            titulo: 'Unirse',
            descripcion: 'Busca una partida cercana y conéctate.',
            alTocar: () {
              red.nombreLocal = nombre;
              red.iniciarInvitado();
            },
          ),
        ] else
          _EstadoLobby(red: red),
        const SizedBox(height: 12),
        _Registro(red: red),
      ],
    );
  }
}

class _TarjetaRol extends StatelessWidget {
  const _TarjetaRol({
    required this.llave,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.alTocar,
  });

  final Key llave;
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$titulo. $descripcion',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          key: llave,
          borderRadius: BorderRadius.circular(12),
          onTap: alTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icono, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
                        Text(descripcion),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerBluetooth extends StatelessWidget {
  const _BannerBluetooth({required this.red});
  final EstadoPartidaRed red;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final bt = red.bt;
    final mensaje = red.mensajeBt ?? bt?.mensaje ?? '';
    return Card(
      key: const Key('banner-bluetooth'),
      color: esquema.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.bluetooth_disabled, color: esquema.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(mensaje,
                    style: TextStyle(color: esquema.onErrorContainer), semanticsLabel: 'Aviso: $mensaje'),
              ),
            ]),
            if (bt == EstadoBluetooth.permisoDenegadoPermanente) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('btn-abrir-ajustes-bt'),
                onPressed: red.abrirAjustes,
                icon: const Icon(Icons.settings),
                label: const Text('Abrir ajustes de la app'),
              ),
            ],
            if (bt == EstadoBluetooth.sinPermiso)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Vuelve a elegir un rol para solicitar el permiso.'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPendiente extends StatelessWidget {
  const _TarjetaPendiente({required this.red});
  final EstadoPartidaRed red;

  @override
  Widget build(BuildContext context) {
    final p = red.pendiente!;
    final cerrada = p.finalizada;
    return Card(
      key: const Key('tarjeta-pendiente'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cerrada
                  ? 'La partida ${p.idPartida} terminó: ${p.descripcionResultado()}'
                  : 'Partida ${p.idPartida} sin terminar',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (!cerrada)
              Text('Eras ${p.rol == RolRed.anfitrion ? 'anfitrión' : 'invitado'} · '
                  '${p.totalJugadas} jugadas · marcador ${p.puntosLocales}-${p.puntosRival}'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (!cerrada)
                FilledButton(
                  key: const Key('btn-recuperar'),
                  onPressed: red.recuperar,
                  child: Text('Recuperar partida ${p.idPartida}'),
                ),
              OutlinedButton(
                key: const Key('btn-descartar'),
                onPressed: red.descartarPendiente,
                child: Text(cerrada ? 'Entendido' : 'Descartar'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _EstadoLobby extends StatelessWidget {
  const _EstadoLobby({required this.red});
  final EstadoPartidaRed red;

  @override
  Widget build(BuildContext context) {
    final anfitrion = red.fase == FaseRed.anunciando;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.bluetooth_searching),
            title: Text(anfitrion
                ? 'Esperando a un jugador…'
                : red.conectando
                    ? 'Conectando…'
                    : red.escaneando
                        ? 'Buscando partidas…'
                        : 'Búsqueda terminada'),
            subtitle: Text(anfitrion
                ? 'Tu partida se anuncia como ${red.nombreAnuncio ?? 'P6-juego'}.'
                : 'Elige la partida a la que quieres unirte.'),
          ),
        ),
        if (!anfitrion) _ListaDispositivos(red: red),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('btn-cancelar-rol'),
          onPressed: red.cancelarRol,
          icon: const Icon(Icons.close),
          label: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _ListaDispositivos extends StatelessWidget {
  const _ListaDispositivos({required this.red});
  final EstadoPartidaRed red;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (red.escaneando) const LinearProgressIndicator(),
        if (red.dispositivos.isEmpty && !red.escaneando)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No se encontraron partidas. Pide al anfitrión que elija «Anfitrión».'),
          ),
        for (final d in red.dispositivos)
          Card(
            child: ListTile(
              key: Key('dispositivo-${d.id}'),
              minTileHeight: 56,
              leading: const Icon(Icons.phone_android),
              title: Text(d.nombre.isEmpty ? 'Dispositivo ${d.id}' : d.nombre),
              subtitle: Text('Señal ${d.rssi} dBm'),
              trailing: const Icon(Icons.login),
              onTap: red.conectando ? null : () => red.conectarCon(d),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('btn-buscar-de-nuevo'),
            onPressed: red.escaneando ? null : red.buscar,
            icon: const Icon(Icons.refresh),
            label: const Text('Buscar de nuevo'),
          ),
        ),
      ],
    );
  }
}

class _Registro extends StatelessWidget {
  const _Registro({required this.red});
  final EstadoPartidaRed red;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: const Key('registro-eventos'),
        leading: const Icon(Icons.list_alt),
        title: Text('Registro de eventos (${red.registro.length})'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: red.registro.isEmpty
                  ? const Text('Sin eventos')
                  : Text(
                      red.registro.reversed.join('\n'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- partida

class _VistaPartida extends StatelessWidget {
  const _VistaPartida({required this.red, required this.visible});
  final EstadoPartidaRed red;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final s = red.sesion!;
    final juego = context.read<EstadoJuego>();
    return AlcanceMovimiento(
      filas: s.filas,
      columnas: s.columnas,
      visible: visible,
      alVoltear: (i) => red.jugarLocal(i),
      builder: (context, control) {
        final pausada = s.estado == EstadoSesionRed.pausadaPorDesconexion;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            _CabeceraPartida(red: red),
            const SizedBox(height: 8),
            if (pausada) _TarjetaReconexion(red: red),
            SizedBox(
              height: 380,
              child: TableroCartas(
                cartas: s.tablero,
                filas: s.filas,
                columnas: s.columnas,
                animaciones: juego.animaciones,
                alTocar: red.jugarLocal,
                cursor: control.encendido ? control.cursor : null,
              ),
            ),
            SwitchMovimiento(control: control),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              key: const Key('btn-salir-red'),
              onPressed: () => _confirmarSalida(context),
              icon: const Icon(Icons.logout),
              label: const Text('Salir'),
            ),
            const SizedBox(height: 8),
            _Diagnostico(red: red),
            const SizedBox(height: 8),
            _Registro(red: red),
          ],
        );
      },
    );
  }

  Future<void> _confirmarSalida(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir de la partida?'),
        content: const Text('El otro jugador será avisado y la partida se dará por abandonada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Seguir jugando')),
          FilledButton(
            key: const Key('btn-confirmar-salir'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true) await red.salir();
  }
}

class _CabeceraPartida extends StatelessWidget {
  const _CabeceraPartida({required this.red});
  final EstadoPartidaRed red;

  @override
  Widget build(BuildContext context) {
    final s = red.sesion!;
    final esquema = Theme.of(context).colorScheme;
    final pausada = s.estado == EstadoSesionRed.pausadaPorDesconexion;
    final conectado = red.conectado && !pausada;
    final miTurno = s.esMiTurno && s.estado == EstadoSesionRed.enJuego;
    final textoTurno = pausada ? 'Partida en pausa' : (s.esMiTurno ? 'Tu turno' : 'Turno del rival');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Semantics(
              label: conectado ? 'Conexión activa' : 'Conexión perdida',
              child: Chip(
                key: const Key('indicador-conexion'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(conectado ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    size: 18, color: conectado ? Colors.green : esquema.error),
                label: Text(conectado ? 'Conectado' : 'Conexión perdida'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${s.rol == RolRed.anfitrion ? 'Anfitrión' : 'Invitado'} · ${s.idPartida}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          key: const Key('banner-turno'),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: miTurno ? esquema.primaryContainer : esquema.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            textoTurno,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: miTurno ? esquema.onPrimaryContainer : null,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Marcador(titulo: 'Tú', puntos: s.puntosLocales, resalta: s.esMiTurno)),
            const SizedBox(width: 8),
            Expanded(
              child: _Marcador(
                  titulo: red.nombreRival ?? 'Rival', puntos: s.puntosRival, resalta: !s.esMiTurno),
            ),
          ],
        ),
      ],
    );
  }
}

class _Marcador extends StatelessWidget {
  const _Marcador({required this.titulo, required this.puntos, required this.resalta});
  final String titulo;
  final int puntos;
  final bool resalta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Puntaje de $titulo: $puntos',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: resalta ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            Text('$puntos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

class _TarjetaReconexion extends StatelessWidget {
  const _TarjetaReconexion({required this.red});
  final EstadoPartidaRed red;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final esInvitado = red.sesion!.rol == RolRed.invitado;
    return Card(
      key: const Key('tarjeta-reconexion'),
      color: esquema.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Conexión perdida',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: esquema.onErrorContainer)),
            Text(esInvitado
                ? 'Busca de nuevo al anfitrión para continuar con REANUDAR.'
                : 'Vuelve a anunciar y espera a que el invitado se reconecte.'),
            if (red.bt != null && !red.bt!.disponible) Text(red.bt!.mensaje),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('btn-reintentar'),
              onPressed: red.reintentarConexion,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar conexión'),
            ),
            if (esInvitado && (red.dispositivos.isNotEmpty || red.escaneando))
              _ListaDispositivos(red: red),
          ],
        ),
      ),
    );
  }
}

class _Diagnostico extends StatelessWidget {
  const _Diagnostico({required this.red});
  final EstadoPartidaRed red;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: const Key('diagnostico-red'),
        leading: const Icon(Icons.bug_report_outlined),
        title: const Text('Diagnóstico'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('btn-reenviar-jugada'),
                onPressed: red.reenviarUltimaJugada,
                child: const Text('Reenviar última jugada (prueba de duplicado)'),
              ),
              OutlinedButton(
                key: const Key('btn-fuera-de-turno'),
                onPressed: red.enviarJugadaFueraDeTurno,
                child: const Text('Jugar fuera de turno'),
              ),
              OutlinedButton(
                key: const Key('btn-jugada-invalida'),
                onPressed: red.enviarJugadaInvalida,
                child: const Text('Enviar jugada inválida'),
              ),
              OutlinedButton(
                key: const Key('btn-version-distinta'),
                onPressed: red.enviarVersionDistinta,
                child: const Text('Enviar versión distinta (v:2)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
