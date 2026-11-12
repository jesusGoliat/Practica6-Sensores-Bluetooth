import 'estado_transferencia.dart';

enum DireccionTransferencia { enviado, recibido }

class RegistroTransferencia {
  const RegistroTransferencia({
    required this.id,
    required this.direccion,
    required this.nombre,
    required this.tipo,
    required this.longitud,
    required this.sha256,
    required this.estado,
    required this.inicio,
    this.progreso = 0,
    this.motivo,
    this.dispositivo,
    this.fin,
  });

  final String id;
  final DireccionTransferencia direccion;
  final String nombre;
  final String tipo;
  final int longitud;
  final String sha256;
  final EstadoTransferencia estado;

  /// Fracción 0..1.
  final double progreso;
  final String? motivo;
  final String? dispositivo;
  final DateTime inicio;
  final DateTime? fin;

  int get bytesTransferidos => (progreso * longitud).round();

  factory RegistroTransferencia.nuevo({
    required String id,
    required DireccionTransferencia direccion,
    required String nombre,
    required String tipo,
    required int longitud,
    String sha256 = '',
    String? dispositivo,
    DateTime? inicio,
  }) =>
      RegistroTransferencia(
        id: id,
        direccion: direccion,
        nombre: nombre,
        tipo: tipo,
        longitud: longitud,
        sha256: sha256,
        estado: EstadoTransferencia.pendiente,
        inicio: inicio ?? DateTime.now(),
        dispositivo: dispositivo,
      );

  RegistroTransferencia conDatos({
    String? nombre,
    String? tipo,
    int? longitud,
    String? sha256,
    String? dispositivo,
    double? progreso,
  }) =>
      RegistroTransferencia(
        id: id,
        direccion: direccion,
        nombre: nombre ?? this.nombre,
        tipo: tipo ?? this.tipo,
        longitud: longitud ?? this.longitud,
        sha256: sha256 ?? this.sha256,
        estado: estado,
        inicio: inicio,
        progreso: progreso ?? this.progreso,
        motivo: motivo,
        dispositivo: dispositivo ?? this.dispositivo,
        fin: fin,
      );

  /// Cambia de estado respetando las transiciones legales. Para `completado`
  /// se exige [verificado] (longitud y SHA-256 comprobados).
  RegistroTransferencia conEstado(
    EstadoTransferencia nuevo, {
    String? motivo,
    bool verificado = false,
    DateTime? ahora,
  }) {
    if (!estado.puedePasarA(nuevo)) {
      throw TransicionInvalida('No se puede pasar de ${estado.name} a ${nuevo.name}.');
    }
    if (nuevo == EstadoTransferencia.completado && !verificado) {
      throw const TransicionInvalida('Solo se completa tras verificar longitud y SHA-256.');
    }
    return RegistroTransferencia(
      id: id,
      direccion: direccion,
      nombre: nombre,
      tipo: tipo,
      longitud: longitud,
      sha256: sha256,
      estado: nuevo,
      inicio: inicio,
      progreso: nuevo == EstadoTransferencia.completado ? 1 : progreso,
      motivo: motivo,
      dispositivo: dispositivo,
      fin: nuevo.esFinal ? (ahora ?? DateTime.now()) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'direccion': direccion.name,
        'nombre': nombre,
        'tipo': tipo,
        'longitud': longitud,
        'sha256': sha256,
        'estado': estado.name,
        'progreso': progreso,
        'motivo': motivo,
        'dispositivo': dispositivo,
        'inicio': inicio.toIso8601String(),
        'fin': fin?.toIso8601String(),
      };

  static RegistroTransferencia? desdeJson(Object? crudo) {
    if (crudo is! Map) return null;
    try {
      final j = Map<String, dynamic>.from(crudo);
      return RegistroTransferencia(
        id: j['id'] as String,
        direccion: DireccionTransferencia.values.byName(j['direccion'] as String),
        nombre: j['nombre'] as String,
        tipo: j['tipo'] as String? ?? '',
        longitud: (j['longitud'] as num?)?.toInt() ?? 0,
        sha256: j['sha256'] as String? ?? '',
        estado: EstadoTransferencia.values.byName(j['estado'] as String),
        progreso: (j['progreso'] as num?)?.toDouble() ?? 0,
        motivo: j['motivo'] as String?,
        dispositivo: j['dispositivo'] as String?,
        inicio: DateTime.parse(j['inicio'] as String),
        fin: j['fin'] == null ? null : DateTime.parse(j['fin'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}
