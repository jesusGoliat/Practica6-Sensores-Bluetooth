import 'dart:math';

import 'carta.dart';
import 'configuracion_partida.dart';
import 'estado_partida.dart';
import 'simbolos.dart';

/// Resultado de voltear una carta: la UI lo usa para animar y programar el
/// ocultamiento de un fallo.
class ResultadoIntento {
  const ResultadoIntento({
    required this.indices,
    required this.acierto,
    required this.esPrimera,
    required this.delta,
    this.esperandoOcultar = false,
    this.categoriaCompletada,
    this.victoria = false,
  });

  final List<int> indices;
  final bool acierto;
  final bool esPrimera;
  final int delta;
  final bool esperandoOcultar;
  final String? categoriaCompletada;
  final bool victoria;
}

/// Motor puro y testeable del memorama. No conoce widgets ni almacenamiento.
class MotorJuego {
  MotorJuego(this._partida);

  EstadoPartida _partida;

  EstadoPartida get partida => _partida;

  static EstadoPartida crearPartida({
    required String nivel,
    required String modo,
    required int semilla,
    required ConfiguracionPartida configuracion,
  }) {
    final filas = nivel == 'laboratorio' ? 6 : 4;
    final columnas = filas;
    final parejas = (filas * columnas) ~/ 2;
    final elegidos = simbolosDisponibles.take(parejas).toList();
    final cartas = <Carta>[
      for (final simbolo in elegidos) ...[
        Carta(simboloId: simbolo.id, categoria: simbolo.categoria.name),
        Carta(simboloId: simbolo.id, categoria: simbolo.categoria.name),
      ],
    ];
    cartas.shuffle(Random(semilla));
    final ahora = DateTime.now();
    final id = '${ahora.millisecondsSinceEpoch}-${semilla.toString().padLeft(6, '0')}';
    return EstadoPartida(
      id: id,
      semilla: semilla,
      nivel: nivel,
      modo: modo,
      filas: filas,
      columnas: columnas,
      tablero: cartas,
      configuracion: configuracion,
      creada: ahora,
      actualizada: ahora,
    );
  }

  List<int> get visibles => <int>[
        for (var i = 0; i < _partida.tablero.length; i++)
          if (_partida.tablero[i].estado == EstadoCarta.visible) i,
      ];

  List<int> get emparejadas => <int>[
        for (var i = 0; i < _partida.tablero.length; i++)
          if (_partida.tablero[i].estado == EstadoCarta.emparejada) i,
      ];

  bool get esperandoOcultar => visibles.length == 2;

  /// Voltea una carta. Devuelve null si la selección no es válida.
  ResultadoIntento? seleccionar(int indice) {
    if (_partida.terminada) return null;
    if (indice < 0 || indice >= _partida.tablero.length) return null;
    if (_partida.tablero[indice].estado != EstadoCarta.oculta) return null;
    if (visibles.length >= 2) return null;

    final tablero = List<Carta>.from(_partida.tablero);
    tablero[indice] = tablero[indice].copyWith(estado: EstadoCarta.visible);
    _partida = _partida.copyWith(tablero: tablero, actualizada: DateTime.now());
    final primera = visibles.length == 1;
    if (primera) {
      return ResultadoIntento(
        indices: <int>[indice],
        acierto: false,
        esPrimera: true,
        delta: 0,
      );
    }

    final anterior = visibles.firstWhere((i) => i != indice);
    final cartaA = _partida.tablero[anterior];
    final cartaB = _partida.tablero[indice];
    final acierto = cartaA.simboloId == cartaB.simboloId;
    if (!acierto) {
      final delta = -min(10, _partida.puntaje);
      _partida = _partida.copyWith(
        puntaje: _partida.puntaje + delta,
        racha: 0,
        actualizada: DateTime.now(),
      );
      _registrarMovimiento(anterior, indice, acierto: false, delta: delta, categoria: cartaA.categoria);
      return ResultadoIntento(
        indices: <int>[anterior, indice],
        acierto: false,
        esPrimera: false,
        delta: delta,
        esperandoOcultar: true,
      );
    }

    final nuevaRacha = _partida.racha + 1;
    final categoria = Categoria.values.firstWhere(
      (c) => c.name == cartaA.categoria,
      orElse: () => Categoria.ipn,
    );
    final estabaCompleta = _partida.categoriaCompleta(categoria);
    final tableroMatch = List<Carta>.from(_partida.tablero);
    tableroMatch[anterior] = tableroMatch[anterior].copyWith(estado: EstadoCarta.emparejada);
    tableroMatch[indice] = tableroMatch[indice].copyWith(estado: EstadoCarta.emparejada);
    _partida = _partida.copyWith(
      tablero: tableroMatch,
      racha: nuevaRacha,
      mejorRacha: max(_partida.mejorRacha, nuevaRacha),
      actualizada: DateTime.now(),
    );
    final completaAhora = !estabaCompleta && _partida.categoriaCompleta(categoria);
    final bonusCategoria = completaAhora ? 150 : 0;
    var delta = 100 + 25 * (nuevaRacha - 1) + bonusCategoria;
    var gano = false;
    var bonusVictoria = 0;
    if (_partida.tablero.every((c) => c.estado == EstadoCarta.emparejada)) {
      gano = true;
      bonusVictoria = _partida.esContrarreloj
          ? max(0, (_partida.limiteSegundos! - _partida.tiempoSegundos) * 2)
          : 500 + _partida.filas * _partida.columnas * 2;
      delta += bonusVictoria;
    }
    _partida = _partida.copyWith(
      puntaje: _partida.puntaje + delta,
      terminada: gano ? true : _partida.terminada,
      actualizada: DateTime.now(),
    );
    _registrarMovimiento(anterior, indice, acierto: true, delta: delta, categoria: cartaA.categoria);
    return ResultadoIntento(
      indices: <int>[anterior, indice],
      acierto: true,
      esPrimera: false,
      delta: delta,
      categoriaCompletada: completaAhora ? categoria.name : null,
      victoria: gano,
    );
  }

  void _registrarMovimiento(
    int a,
    int b, {
    required bool acierto,
    required int delta,
    required String categoria,
  }) {
    final movimiento = Movimiento(
      numero: _partida.movimientos.length + 1,
      indiceA: a,
      indiceB: b,
      simboloA: _partida.tablero[a].simboloId,
      simboloB: _partida.tablero[b].simboloId,
      acierto: acierto,
      deltaPuntaje: delta,
      tiempoSegundos: _partida.tiempoSegundos,
      categoria: categoria,
    );
    _partida = _partida.copyWith(
      movimientos: <Movimiento>[..._partida.movimientos, movimiento],
      actualizada: DateTime.now(),
    );
  }

  /// Oculta las dos cartas visibles después de un fallo.
  void ocultarPendientes() {
    if (!esperandoOcultar) return;
    final tablero = List<Carta>.from(_partida.tablero);
    for (var i = 0; i < tablero.length; i++) {
      if (tablero[i].estado == EstadoCarta.visible) {
        tablero[i] = tablero[i].copyWith(estado: EstadoCarta.oculta);
      }
    }
    _partida = _partida.copyWith(tablero: tablero, actualizada: DateTime.now());
  }

  /// Actualiza el reloj lógico de la partida. Devuelve true si el tiempo
  /// agotó una partida de contrarreloj.
  bool actualizarTiempo(int segundos) {
    if (_partida.terminada) return false;
    final nuevo = _partida.copyWith(tiempoSegundos: segundos, actualizada: DateTime.now());
    _partida = nuevo;
    if (_partida.esContrarreloj &&
        _partida.tiempoSegundos >= _partida.limiteSegundos! &&
        !_partida.terminada) {
      _partida = _partida.copyWith(terminada: true, perdida: true, actualizada: DateTime.now());
      return true;
    }
    return false;
  }

  void reemplazar(EstadoPartida partida) {
    _partida = partida;
  }
}
