import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_juego.dart';
import '../dominio/carta.dart';
import 'widgets/carta_animada.dart';
import 'widgets/confeti.dart';

class PantallaJuego extends StatefulWidget {
  const PantallaJuego({super.key});

  @override
  State<PantallaJuego> createState() => _PantallaJuegoState();
}

class _PantallaJuegoState extends State<PantallaJuego> {
  late final EstadoJuego _juego;

  @override
  void initState() {
    super.initState();
    _juego = context.read<EstadoJuego>();
  }

  @override
  void dispose() {
    _juego.autoguardarAhora();
    if (_juego.activa) _juego.pausar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final juego = context.watch<EstadoJuego>();
    final partida = juego.partida;
    if (partida == null) {
      return const Scaffold(body: Center(child: Text('No hay una partida activa.')));
    }
    final cuerpo = Column(
      children: [
        _Estadisticas(juego: juego),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: partida.progreso,
              minHeight: 8,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        Expanded(child: _Tablero(juego: juego)),
        _Pie(juego: juego),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(partida.nivelEtiqueta, style: const TextStyle(fontSize: 16)),
            Text(
              partida.modoEtiqueta,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('btn-pausa'),
            tooltip: juego.pausado ? T.reanudar : T.pausa,
            onPressed: () => juego.pausado ? juego.reanudar() : juego.pausar(),
            icon: Icon(juego.pausado ? Icons.play_arrow : Icons.pause),
          ),
          IconButton(
            key: const Key('btn-guardar-partida'),
            tooltip: T.guardarPartida,
            onPressed: () => _guardar(context, juego),
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            key: const Key('btn-reiniciar'),
            tooltip: T.reiniciar,
            onPressed: () => _reiniciar(context, juego),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: Stack(
        children: [
          cuerpo,
          if (juego.pausado) _Pausa(juego: juego, alSalir: () => Navigator.of(context).pop()),
          if (partida.terminada)
            Positioned.fill(
              child: _Resultado(
                juego: juego,
                alGuardar: () => _guardar(context, juego),
                alSalir: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _guardar(BuildContext context, EstadoJuego juego) async {
    final nombre = TextEditingController();
    final etiqueta = TextEditingController(text: juego.partida?.etiqueta ?? '');
    var formato = juego.formato;
    await showDialog<void>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, setEstado) => AlertDialog(
          title: const Text(T.guardarPartida),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('dlg-nombre-partida'),
                  controller: nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (opcional)',
                    hintText: 'Se genera uno automáticamente',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('dlg-etiqueta-partida'),
                  controller: etiqueta,
                  decoration: const InputDecoration(
                    labelText: T.etiqueta,
                    hintText: 'Ej. rápida, examen, práctica',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('dlg-formato-partida'),
                  initialValue: formato,
                  decoration: const InputDecoration(labelText: T.formatoGuardado),
                  items: const [
                    DropdownMenuItem(value: 'json', child: Text('JSON (.json)')),
                    DropdownMenuItem(value: 'xml', child: Text('XML (.xml)')),
                    DropdownMenuItem(value: 'txt', child: Text('Texto plano (.txt)')),
                  ],
                  onChanged: (v) => setEstado(() => formato = v ?? 'json'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexto), child: const Text(T.cancelar)),
            FilledButton(
              key: const Key('btn-confirmar-guardado'),
              onPressed: () async {
                await juego.guardar(
                  nombre: nombre.text.trim().isEmpty ? null : nombre.text.trim(),
                  formatoElegido: formato,
                  etiqueta: etiqueta.text.trim(),
                );
                if (contexto.mounted) Navigator.pop(contexto);
              },
              child: const Text(T.guardar),
            ),
          ],
        ),
      ),
    );
    nombre.dispose();
    etiqueta.dispose();
  }

  Future<void> _reiniciar(BuildContext context, EstadoJuego juego) async {
    final confirmar = await confirmarAccion(
      context,
      titulo: T.reiniciar,
      mensaje: 'Se perderá el avance de esta partida. ¿Quieres empezar de nuevo?',
      textoConfirmar: T.reiniciar,
      destructivo: true,
    );
    if (confirmar) juego.reiniciar();
  }
}

class _Estadisticas extends StatelessWidget {
  const _Estadisticas({required this.juego});

  final EstadoJuego juego;

  @override
  Widget build(BuildContext context) {
    final partida = juego.partida!;
    final esquema = Theme.of(context).colorScheme;
    final tiempo = partida.esContrarreloj
        ? Formato.duracion(partida.restante)
        : Formato.duracion(partida.tiempoSegundos);
    final alerta = partida.esContrarreloj && partida.restante <= 15;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _Dato(
              titulo: T.puntaje,
              valor: '${partida.puntaje}',
              icono: Icons.stars_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Dato(
              titulo: T.tiempo,
              valor: tiempo,
              icono: Icons.timer_outlined,
              color: alerta ? esquema.error : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Dato(
              titulo: 'Movs.',
              valor: '${partida.movimientos.length}',
              icono: Icons.touch_app_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Dato(
              titulo: 'Racha',
              valor: '${partida.racha}',
              icono: Icons.local_fire_department_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.titulo, required this.valor, required this.icono, this.color});

  final String titulo;
  final String valor;
  final IconData icono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              valor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tablero extends StatelessWidget {
  const _Tablero({required this.juego});

  final EstadoJuego juego;

  @override
  Widget build(BuildContext context) {
    final partida = juego.partida!;
    return LayoutBuilder(
      builder: (context, constraints) {
        const separacion = 6.0;
        final maxAncho = constraints.maxWidth - 24;
        final maxAlto = constraints.maxHeight - 12;
        final anchoCelda = (maxAncho - (partida.columnas - 1) * separacion) / partida.columnas;
        final altoCelda = (maxAlto - (partida.filas - 1) * separacion) / partida.filas;
        final lado = anchoCelda < altoCelda ? anchoCelda : altoCelda;
        final ancho = lado * partida.columnas + (partida.columnas - 1) * separacion;
        final alto = lado * partida.filas + (partida.filas - 1) * separacion;
        return Center(
          child: SizedBox(
            width: ancho.clamp(0, maxAncho),
            height: alto.clamp(0, maxAlto),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: partida.columnas,
                mainAxisSpacing: separacion,
                crossAxisSpacing: separacion,
              ),
              itemCount: partida.tablero.length,
              itemBuilder: (context, i) {
                final Carta carta = partida.tablero[i];
                return CartaAnimada(
                  carta: carta,
                  indice: i,
                  animaciones: juego.animaciones,
                  alTocar: () => juego.voltear(i),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({required this.juego});

  final EstadoJuego juego;

  @override
  Widget build(BuildContext context) {
    final partida = juego.partida!;
    final esquema = Theme.of(context).colorScheme;
    final texto = juego.pausado
        ? 'Partida en pausa'
        : juego.esperandoOcultar
            ? 'Observa las cartas…'
            : partida.terminada
                ? (partida.victoria ? '¡Completaste el tablero!' : T.tiempoAgotado)
                : 'Toca dos cartas para buscar una pareja.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: esquema.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (partida.esContrarreloj)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('Límite ${Formato.duracion(partida.limiteSegundos ?? 0)}'),
            ),
        ],
      ),
    );
  }
}

class _Pausa extends StatelessWidget {
  const _Pausa({required this.juego, required this.alSalir});

  final EstadoJuego juego;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pause_circle_outline, size: 48),
                  const SizedBox(height: 8),
                  Text(T.pausa, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('btn-reanudar'),
                    onPressed: juego.reanudar,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(T.reanudar),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: alSalir,
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Volver al inicio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.juego,
    required this.alGuardar,
    required this.alSalir,
  });

  final EstadoJuego juego;
  final VoidCallback alGuardar;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    final partida = juego.partida!;
    final esquema = Theme.of(context).colorScheme;
    return Stack(
      children: [
        if (partida.victoria) const Positioned.fill(child: Confeti()),
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black54,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          partida.victoria ? Icons.emoji_events : Icons.timer_off_outlined,
                          size: 56,
                          color: partida.victoria ? esquema.tertiary : esquema.error,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          partida.victoria ? T.victoria : T.tiempoAgotado,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        _LineaResultado(etiqueta: T.puntaje, valor: '${partida.puntaje}'),
                        _LineaResultado(etiqueta: T.tiempo, valor: Formato.duracion(partida.tiempoSegundos)),
                        _LineaResultado(etiqueta: T.movimientos, valor: '${partida.movimientos.length}'),
                        _LineaResultado(etiqueta: 'Mejor racha', valor: '${partida.mejorRacha}'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          key: const Key('btn-guardar-resultado'),
                          onPressed: alGuardar,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text(T.guardarPartida),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('btn-nueva-partida-resultado'),
                          onPressed: () {
                            juego.reiniciar();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text(T.nuevaPartida),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          key: const Key('btn-inicio-resultado'),
                          onPressed: alSalir,
                          child: const Text('Volver al inicio'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineaResultado extends StatelessWidget {
  const _LineaResultado({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
