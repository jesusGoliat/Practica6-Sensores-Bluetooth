import 'carta.dart';
import 'configuracion_partida.dart';
import 'simbolos.dart';

/// Estado completo de una partida. Es la única fuente de verdad para guardar
/// en TXT, XML y JSON, y para reanudar después de cerrar la app.
class EstadoPartida {
  EstadoPartida({
    required this.id,
    required this.semilla,
    required this.nivel,
    required this.modo,
    required this.filas,
    required this.columnas,
    required this.tablero,
    required this.configuracion,
    required this.creada,
    required this.actualizada,
    this.version = 1,
    this.puntaje = 0,
    this.tiempoSegundos = 0,
    this.terminada = false,
    this.perdida = false,
    this.racha = 0,
    this.mejorRacha = 0,
    this.movimientos = const <Movimiento>[],
    this.etiqueta = '',
  });

  static const String esquema = 'memorama-ipn';
  static const int versionActual = 1;

  final int version;
  final String id;
  final int semilla;
  final String nivel;
  final String modo;
  final int filas;
  final int columnas;
  final List<Carta> tablero;
  final int puntaje;
  final int tiempoSegundos;
  final bool terminada;
  final bool perdida;
  final int racha;
  final int mejorRacha;
  final ConfiguracionPartida configuracion;
  final List<Movimiento> movimientos;
  final DateTime creada;
  final DateTime actualizada;
  final String etiqueta;

  int get totalCartas => tablero.length;
  int get emparejadas => tablero.where((c) => c.estado == EstadoCarta.emparejada).length;
  double get progreso => totalCartas == 0 ? 0 : emparejadas / totalCartas;
  bool get esContrarreloj => modo == 'contrarreloj';
  int? get limiteSegundos => esContrarreloj ? (filas <= 4 ? 90 : 180) : null;
  int get restante => limiteSegundos == null ? 0 : (limiteSegundos! - tiempoSegundos).clamp(0, limiteSegundos!);
  bool get victoria => terminada && !perdida;

  String get nivelEtiqueta => nivel == 'laboratorio' ? 'Laboratorio (6×6)' : 'Campus (4×4)';
  String get modoEtiqueta => esContrarreloj ? 'Contrarreloj' : 'Relajado';

  bool categoriaCompleta(Categoria categoria) {
    final cartas = tablero.where((c) => c.categoria == categoria.name);
    return cartas.isNotEmpty && cartas.every((c) => c.estado == EstadoCarta.emparejada);
  }

  EstadoPartida copia({bool profunda = true}) => EstadoPartida(
        version: version,
        id: id,
        semilla: semilla,
        nivel: nivel,
        modo: modo,
        filas: filas,
        columnas: columnas,
        tablero: profunda ? List<Carta>.from(tablero) : tablero,
        puntaje: puntaje,
        tiempoSegundos: tiempoSegundos,
        terminada: terminada,
        perdida: perdida,
        racha: racha,
        mejorRacha: mejorRacha,
        configuracion: configuracion,
        movimientos: profunda ? List<Movimiento>.from(movimientos) : movimientos,
        creada: creada,
        actualizada: actualizada,
        etiqueta: etiqueta,
      );

  EstadoPartida copyWith({
    int? puntaje,
    int? tiempoSegundos,
    bool? terminada,
    bool? perdida,
    int? racha,
    int? mejorRacha,
    ConfiguracionPartida? configuracion,
    List<Movimiento>? movimientos,
    DateTime? actualizada,
    String? etiqueta,
    List<Carta>? tablero,
  }) =>
      EstadoPartida(
        version: version,
        id: id,
        semilla: semilla,
        nivel: nivel,
        modo: modo,
        filas: filas,
        columnas: columnas,
        tablero: tablero ?? this.tablero,
        puntaje: puntaje ?? this.puntaje,
        tiempoSegundos: tiempoSegundos ?? this.tiempoSegundos,
        terminada: terminada ?? this.terminada,
        perdida: perdida ?? this.perdida,
        racha: racha ?? this.racha,
        mejorRacha: mejorRacha ?? this.mejorRacha,
        configuracion: configuracion ?? this.configuracion,
        movimientos: movimientos ?? this.movimientos,
        creada: creada,
        actualizada: actualizada ?? this.actualizada,
        etiqueta: etiqueta ?? this.etiqueta,
      );

  /// Mapa canónico: el mismo que consumen JSON, XML y TXT. El checksum se
  /// agrega en los codificadores, no aquí.
  Map<String, Object?> aJson() => <String, Object?>{
        'schema': esquema,
        'version': version,
        'id': id,
        'semilla': semilla,
        'nivel': nivel,
        'modo': modo,
        'filas': filas,
        'columnas': columnas,
        'puntaje': puntaje,
        'tiempoSegundos': tiempoSegundos,
        'terminada': terminada,
        'perdida': perdida,
        'racha': racha,
        'mejorRacha': mejorRacha,
        'etiqueta': etiqueta,
        'creada': creada.toIso8601String(),
        'actualizada': actualizada.toIso8601String(),
        'configuracion': configuracion.aJson(),
        'tablero': tablero.map((c) => c.aJson()).toList(),
        'movimientos': movimientos.map((m) => m.aJson()).toList(),
      };

  factory EstadoPartida.desdeJson(Map<String, Object?> json) {
    final tableroJson = (json['tablero'] as List<dynamic>? ?? <dynamic>[]);
    final movimientosJson = (json['movimientos'] as List<dynamic>? ?? <dynamic>[]);
    final configJson = json['configuracion'];
    return EstadoPartida(
      version: (json['version'] as num?)?.toInt() ?? 1,
      id: json['id'] as String? ?? '',
      semilla: (json['semilla'] as num?)?.toInt() ?? 0,
      nivel: json['nivel'] as String? ?? 'campus',
      modo: json['modo'] as String? ?? 'relajado',
      filas: (json['filas'] as num?)?.toInt() ?? 4,
      columnas: (json['columnas'] as num?)?.toInt() ?? 4,
      tablero: tableroJson
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Carta.desdeJson(Map<String, Object?>.from(m)))
          .toList(),
      puntaje: (json['puntaje'] as num?)?.toInt() ?? 0,
      tiempoSegundos: (json['tiempoSegundos'] as num?)?.toInt() ?? 0,
      terminada: json['terminada'] as bool? ?? false,
      perdida: json['perdida'] as bool? ?? false,
      racha: (json['racha'] as num?)?.toInt() ?? 0,
      mejorRacha: (json['mejorRacha'] as num?)?.toInt() ?? 0,
      configuracion: configJson is Map
          ? ConfiguracionPartida.desdeJson(Map<String, Object?>.from(configJson))
          : const ConfiguracionPartida(),
      movimientos: movimientosJson
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => Movimiento.desdeJson(Map<String, Object?>.from(m)))
          .toList(),
      creada: DateTime.tryParse(json['creada'] as String? ?? '') ?? DateTime.now(),
      actualizada: DateTime.tryParse(json['actualizada'] as String? ?? '') ?? DateTime.now(),
      etiqueta: json['etiqueta'] as String? ?? '',
    );
  }

  /// Resumen para la lista de partidas guardadas.
  Map<String, Object?> aResumen() => <String, Object?>{
        'id': id,
        'nivel': nivel,
        'modo': modo,
        'puntaje': puntaje,
        'tiempoSegundos': tiempoSegundos,
        'terminada': terminada,
        'perdida': perdida,
        'etiqueta': etiqueta,
        'creada': creada.toIso8601String(),
      };

  List<String> get simbolosUsados =>
      tablero.map((c) => simboloPorId(c.simboloId).etiqueta).toSet().toList();
}
