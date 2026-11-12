import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_juego.dart';
import '../datos/repositorio_partidas.dart';
import 'pantalla_juego.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key, required this.alVerPartidas});

  final VoidCallback alVerPartidas;

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  late String _nivel;
  late String _modo;

  @override
  void initState() {
    super.initState();
    final juego = context.read<EstadoJuego>();
    _nivel = juego.nivelPreferido;
    _modo = juego.modoPreferido;
  }

  @override
  Widget build(BuildContext context) {
    final juego = context.watch<EstadoJuego>();
    final esquema = Theme.of(context).colorScheme;
    final progreso = juego.progreso;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _Portada(),
        const SizedBox(height: 16),
        if (juego.hayAutoguardado)
          Card(
            color: esquema.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Partida sin terminar', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${juego.autoguardado!.nivelEtiqueta} · ${juego.autoguardado!.modoEtiqueta} · '
                    '${juego.autoguardado!.puntaje} puntos · ${Formato.duracion(juego.autoguardado!.tiempoSegundos)}',
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const Key('btn-continuar'),
                    onPressed: () {
                      juego.continuarAutoguardado();
                      _abrirJuego(context);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(T.continuar),
                  ),
                ],
              ),
            ),
          ),
        if (juego.activa)
          Card(
            child: ListTile(
              leading: const Icon(Icons.sports_esports),
              title: const Text('Partida en curso'),
              subtitle: Text(
                '${juego.partida!.nivelEtiqueta} · ${juego.partida!.modoEtiqueta} · '
                '${juego.partida!.puntaje} puntos',
              ),
              trailing: FilledButton(
                key: const Key('btn-partida-en-curso'),
                onPressed: () => _abrirJuego(context),
                child: const Text('Volver'),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text('Nueva partida', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(T.nivel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'campus', label: Text(T.campus), icon: Icon(Icons.school_outlined)),
            ButtonSegment(value: 'laboratorio', label: Text(T.laboratorio), icon: Icon(Icons.science_outlined)),
          ],
          selected: {_nivel},
          onSelectionChanged: (v) => setState(() => _nivel = v.first),
        ),
        const SizedBox(height: 12),
        Text(T.modo, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'relajado', label: Text(T.relajado), icon: Icon(Icons.self_improvement)),
            ButtonSegment(value: 'contrarreloj', label: Text(T.contrarreloj), icon: Icon(Icons.timer_outlined)),
          ],
          selected: {_modo},
          onSelectionChanged: (v) => setState(() => _modo = v.first),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('btn-jugar'),
          onPressed: () => _nuevaPartida(context, juego),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text(T.jugar),
        ),
        const SizedBox(height: 24),
        Text(T.progreso, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DatoProgreso(
                titulo: T.mejorPuntaje,
                valor: '${progreso.mejor('campus')}',
                detalle: T.campus,
                icono: Icons.school_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DatoProgreso(
                titulo: T.mejorPuntaje,
                valor: '${progreso.mejor('laboratorio')}',
                detalle: T.laboratorio,
                icono: Icons.science_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DatoProgreso(
                titulo: T.partidasJugadas,
                valor: '${progreso.partidasJugadas}',
                detalle: '${progreso.nivelesCompletados.length} niveles',
                icono: Icons.emoji_events_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Text(T.partidas, style: Theme.of(context).textTheme.titleLarge)),
            TextButton(
              onPressed: widget.alVerPartidas,
              child: const Text('Ver todas'),
            ),
          ],
        ),
        if (juego.partidas.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.save_outlined),
              title: Text(T.sinPartidas),
              subtitle: Text('Guarda una partida desde el menú del juego para verla aquí.'),
            ),
          )
        else
          for (final guardada in juego.partidas.take(3)) _FilaPartida(guardada: guardada),
      ],
    );
  }

  Future<void> _nuevaPartida(BuildContext context, EstadoJuego juego) async {
    if (juego.activa) {
      final confirmar = await confirmarAccion(
        context,
        titulo: 'Empezar otra partida',
        mensaje: 'Hay una partida en curso. Se guardará el estado actual antes de empezar.',
        textoConfirmar: 'Empezar',
        destructivo: true,
      );
      if (!confirmar) return;
      await juego.autoguardarAhora();
    }
    juego.nuevaPartida(nivel: _nivel, modo: _modo);
    if (context.mounted) _abrirJuego(context);
  }

  void _abrirJuego(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PantallaJuego()),
    );
  }
}

class _Portada extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [esquema.primary, esquema.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.extension, color: esquema.onPrimary, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pares Politécnicos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: esquema.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Memorama del campus: encuentra las parejas, completa categorías y '
            'supera tu mejor puntaje. Funciona sin conexión y guarda tus partidas '
            'en TXT, XML o JSON.',
            style: TextStyle(color: esquema.onPrimary.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _DatoProgreso extends StatelessWidget {
  const _DatoProgreso({
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.icono,
  });

  final String titulo;
  final String valor;
  final String detalle;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20),
            const SizedBox(height: 6),
            Text(valor, style: Theme.of(context).textTheme.headlineSmall),
            Text(titulo, style: Theme.of(context).textTheme.labelSmall),
            Text(
              detalle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaPartida extends StatelessWidget {
  const _FilaPartida({required this.guardada});

  final PartidaGuardada guardada;

  @override
  Widget build(BuildContext context) {
    final estado = guardada.estado;
    return Card(
      child: ListTile(
        leading: Icon(
          estado?.victoria == true ? Icons.emoji_events : Icons.save_outlined,
          color: estado?.victoria == true ? Theme.of(context).colorScheme.tertiary : null,
        ),
        title: Text(guardada.nombreVisible, overflow: TextOverflow.ellipsis),
        subtitle: estado == null
            ? Text(guardada.error ?? T.corrupta)
            : Text(
                '${estado.nivelEtiqueta} · ${estado.modoEtiqueta} · ${estado.puntaje} pts · '
                '${Formato.fecha(guardada.modificada)}',
              ),
        trailing: Text(guardada.formato),
      ),
    );
  }
}
