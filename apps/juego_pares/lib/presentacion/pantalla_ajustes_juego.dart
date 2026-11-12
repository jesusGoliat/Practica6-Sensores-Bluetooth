import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_juego.dart';
import '../datos/estado_tema_juego.dart';

class PantallaAjustesJuego extends StatefulWidget {
  const PantallaAjustesJuego({super.key});

  @override
  State<PantallaAjustesJuego> createState() => _PantallaAjustesJuegoState();
}

class _PantallaAjustesJuegoState extends State<PantallaAjustesJuego> {
  late final TextEditingController _nombre;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: context.read<EstadoJuego>().nombreJugador);
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<EstadoTemaJuego>();
    final juego = context.watch<EstadoJuego>();
    final esquema = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Apariencia', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('ajustes-juego-guinda'),
              label: const Text(T.temaGuinda),
              selected: tema.visual == TemaVisual.guinda,
              onSelected: (_) => tema.cambiarVisual(TemaVisual.guinda),
            ),
            ChoiceChip(
              key: const Key('ajustes-juego-azul'),
              label: const Text(T.temaAzul),
              selected: tema.visual == TemaVisual.azul,
              onSelected: (_) => tema.cambiarVisual(TemaVisual.azul),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text(T.modoSistema), icon: Icon(Icons.brightness_auto)),
            ButtonSegment(value: ThemeMode.light, label: Text(T.modoClaro), icon: Icon(Icons.light_mode)),
            ButtonSegment(value: ThemeMode.dark, label: Text(T.modoOscuro), icon: Icon(Icons.dark_mode)),
          ],
          selected: {tema.modo},
          onSelectionChanged: (v) => tema.cambiarModo(v.first),
        ),
        const Divider(height: 32),
        Text('Jugabilidad', style: Theme.of(context).textTheme.titleMedium),
        SwitchListTile(
          key: const Key('switch-sonido'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.volume_up_outlined),
          title: const Text(T.sonido),
          subtitle: const Text('Efectos al voltear, acertar, fallar y ganar'),
          value: juego.sonidoActivo,
          onChanged: (v) => juego.configurarSonido(v),
        ),
        SwitchListTile(
          key: const Key('switch-animaciones'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.animation),
          title: const Text(T.animaciones),
          subtitle: const Text('Volteo, pulso y confeti'),
          value: juego.animaciones,
          onChanged: (v) => juego.configurarAnimaciones(v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.music_note_outlined),
          title: const Text('Probar sonido'),
          trailing: OutlinedButton(
            onPressed: juego.sonidoActivo ? juego.probarSonido : null,
            child: const Text('Probar'),
          ),
        ),
        const Divider(height: 32),
        Text(T.formatoGuardado, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('formato-preferido'),
          initialValue: juego.formato,
          decoration: const InputDecoration(
            helperText: 'Se usa al guardar y para el guardado final automático.',
          ),
          items: const [
            DropdownMenuItem(value: 'json', child: Text('JSON (.json)')),
            DropdownMenuItem(value: 'xml', child: Text('XML (.xml)')),
            DropdownMenuItem(value: 'txt', child: Text('Texto plano (.txt)')),
          ],
          onChanged: (v) => juego.configurarFormato(v ?? 'json'),
        ),
        const SizedBox(height: 16),
        Text(T.nombreJugador, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('campo-nombre-jugador'),
                controller: _nombre,
                decoration: const InputDecoration(labelText: T.nombreJugador),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => juego.configurarNombre(_nombre.text),
              child: const Text(T.guardar),
            ),
          ],
        ),
        const Divider(height: 32),
        Text('Almacenamiento', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Carpeta privada de partidas'),
          subtitle: Text(
            '${juego.partidas.length} archivo(s) en el almacenamiento privado de la app. '
            'Las partidas se guardan en TXT, XML o JSON según el formato elegido.',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.autorenew),
          title: const Text('Autoguardado'),
          subtitle: Text(
            juego.hayAutoguardado
                ? 'Hay una partida sin terminar lista para continuar.'
                : 'Se guarda automáticamente después de cada movimiento.',
          ),
        ),
        const Divider(height: 32),
        Text(T.acercaDe, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.extension),
          title: Text(T.appJuego),
          subtitle: Text('Práctica 4 · Flutter · Android e iOS · 100 % offline'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.verified_outlined),
          title: Text('Versión'),
          subtitle: Text('1.0.0'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Categorías: Ciencias, Ingeniería, Cómputo e IPN. Completar una categoría '
            'otorga 150 puntos extra.',
            style: TextStyle(color: esquema.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
