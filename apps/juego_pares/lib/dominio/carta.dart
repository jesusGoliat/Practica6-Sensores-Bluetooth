/// Estado de una carta en el tablero.
enum EstadoCarta { oculta, visible, emparejada }

/// Una carta del tablero. Se guarda solo su símbolo y estado; la posición es
/// el índice en la lista, lo que hace estable la serialización.
class Carta {
  const Carta({
    required this.simboloId,
    this.categoria = '',
    this.estado = EstadoCarta.oculta,
  });

  final String simboloId;
  final String categoria;
  final EstadoCarta estado;

  Carta copyWith({String? simboloId, String? categoria, EstadoCarta? estado}) => Carta(
        simboloId: simboloId ?? this.simboloId,
        categoria: categoria ?? this.categoria,
        estado: estado ?? this.estado,
      );

  Map<String, Object?> aJson() => <String, Object?>{
        'simbolo': simboloId,
        'categoria': categoria,
        'estado': estado.name,
      };

  factory Carta.desdeJson(Map<String, Object?> json) => Carta(
        simboloId: json['simbolo'] as String? ?? '',
        categoria: json['categoria'] as String? ?? '',
        estado: EstadoCarta.values.firstWhere(
          (e) => e.name == json['estado'],
          orElse: () => EstadoCarta.oculta,
        ),
      );
}

/// Un intento (dos cartas volteadas) con su resultado y puntaje.
class Movimiento {
  const Movimiento({
    required this.numero,
    required this.indiceA,
    required this.indiceB,
    required this.simboloA,
    required this.simboloB,
    required this.acierto,
    required this.deltaPuntaje,
    required this.tiempoSegundos,
    required this.categoria,
  });

  final int numero;
  final int indiceA;
  final int indiceB;
  final String simboloA;
  final String simboloB;
  final bool acierto;
  final int deltaPuntaje;
  final int tiempoSegundos;
  final String categoria;

  Map<String, Object?> aJson() => <String, Object?>{
        'numero': numero,
        'indiceA': indiceA,
        'indiceB': indiceB,
        'simboloA': simboloA,
        'simboloB': simboloB,
        'acierto': acierto,
        'deltaPuntaje': deltaPuntaje,
        'tiempoSegundos': tiempoSegundos,
        'categoria': categoria,
      };

  factory Movimiento.desdeJson(Map<String, Object?> json) => Movimiento(
        numero: (json['numero'] as num?)?.toInt() ?? 0,
        indiceA: (json['indiceA'] as num?)?.toInt() ?? 0,
        indiceB: (json['indiceB'] as num?)?.toInt() ?? 0,
        simboloA: json['simboloA'] as String? ?? '',
        simboloB: json['simboloB'] as String? ?? '',
        acierto: json['acierto'] as bool? ?? false,
        deltaPuntaje: (json['deltaPuntaje'] as num?)?.toInt() ?? 0,
        tiempoSegundos: (json['tiempoSegundos'] as num?)?.toInt() ?? 0,
        categoria: json['categoria'] as String? ?? '',
      );

  String aLinea() =>
      '$indiceA|$indiceB|${acierto ? 1 : 0}|$deltaPuntaje|$tiempoSegundos|$simboloA|$simboloB|$categoria|$numero';

  factory Movimiento.desdeLinea(String linea) {
    final partes = linea.split('|');
    return Movimiento(
      indiceA: int.tryParse(partes[0]) ?? 0,
      indiceB: int.tryParse(partes[1]) ?? 0,
      acierto: partes.length > 2 && partes[2] == '1',
      deltaPuntaje: partes.length > 3 ? int.tryParse(partes[3]) ?? 0 : 0,
      tiempoSegundos: partes.length > 4 ? int.tryParse(partes[4]) ?? 0 : 0,
      simboloA: partes.length > 5 ? partes[5] : '',
      simboloB: partes.length > 6 ? partes[6] : '',
      categoria: partes.length > 7 ? partes[7] : '',
      numero: partes.length > 8 ? int.tryParse(partes[8]) ?? 0 : 0,
    );
  }
}
