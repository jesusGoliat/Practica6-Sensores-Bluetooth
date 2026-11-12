import 'package:flutter/foundation.dart';

/// Origen de un archivo o carpeta. Determina qué API se usa para operarlo.
enum OrigenArchivo { privado, saf, iosSeguro }

extension OrigenArchivoTexto on OrigenArchivo {
  String get etiqueta => switch (this) {
        OrigenArchivo.privado => 'Espacio de la app',
        OrigenArchivo.saf => 'Carpeta autorizada (SAF)',
        OrigenArchivo.iosSeguro => 'Carpeta autorizada (iOS)',
      };
}

/// Raíz autorizada: el espacio privado o una carpeta elegida por el usuario.
@immutable
class RaizAutorizada {
  const RaizAutorizada({
    required this.id,
    required this.nombre,
    required this.origen,
    required this.referencia,
    this.token,
    this.soloLectura = false,
    this.disponible = true,
  });

  final String id;
  final String nombre;
  final OrigenArchivo origen;

  /// Ruta absoluta (privado/iOS) o `content://` (SAF).
  final String referencia;

  /// Bookmark Base64 de iOS para volver a abrir la carpeta.
  final String? token;
  final bool soloLectura;
  final bool disponible;

  RaizAutorizada copyWith({
    String? nombre,
    String? referencia,
    String? token,
    bool? disponible,
    bool? soloLectura,
  }) =>
      RaizAutorizada(
        id: id,
        nombre: nombre ?? this.nombre,
        origen: origen,
        referencia: referencia ?? this.referencia,
        token: token ?? this.token,
        soloLectura: soloLectura ?? this.soloLectura,
        disponible: disponible ?? this.disponible,
      );

  Map<String, Object?> aJson() => <String, Object?>{
        'id': id,
        'nombre': nombre,
        'origen': origen.name,
        'referencia': referencia,
        'token': token,
        'soloLectura': soloLectura,
      };

  factory RaizAutorizada.desdeJson(Map<String, Object?> json) => RaizAutorizada(
        id: json['id'] as String,
        nombre: json['nombre'] as String? ?? 'Carpeta',
        origen: OrigenArchivo.values.firstWhere(
          (o) => o.name == json['origen'],
          orElse: () => OrigenArchivo.privado,
        ),
        referencia: json['referencia'] as String? ?? '',
        token: json['token'] as String?,
        soloLectura: json['soloLectura'] as bool? ?? false,
      );
}

/// Entrada visible en el explorador.
@immutable
class EntradaArchivo {
  const EntradaArchivo({
    required this.nombre,
    required this.referencia,
    required this.esCarpeta,
    required this.origen,
    required this.raiz,
    this.tamano,
    this.modificado,
    this.creado,
    this.mime,
    this.utType,
    this.soloLectura = false,
    this.disponible = true,
  });

  final String nombre;

  /// Ruta o URI que identifica la entrada dentro de su raíz.
  final String referencia;
  final bool esCarpeta;
  final OrigenArchivo origen;
  final RaizAutorizada raiz;
  final int? tamano;
  final DateTime? modificado;
  final DateTime? creado;
  final String? mime;
  final String? utType;
  final bool soloLectura;
  final bool disponible;

  String get clave => '${origen.name}:$referencia';

  EntradaArchivo copyWith({
    String? nombre,
    String? referencia,
    bool? disponible,
    bool? soloLectura,
    int? tamano,
    DateTime? modificado,
  }) =>
      EntradaArchivo(
        nombre: nombre ?? this.nombre,
        referencia: referencia ?? this.referencia,
        esCarpeta: esCarpeta,
        origen: origen,
        raiz: raiz,
        tamano: tamano ?? this.tamano,
        modificado: modificado ?? this.modificado,
        creado: creado,
        mime: mime,
        utType: utType,
        soloLectura: soloLectura ?? this.soloLectura,
        disponible: disponible ?? this.disponible,
      );

  Map<String, Object?> aJson() => <String, Object?>{
        'nombre': nombre,
        'referencia': referencia,
        'esCarpeta': esCarpeta,
        'origen': origen.name,
        'tamano': tamano,
        'modificado': modificado?.toIso8601String(),
        'creado': creado?.toIso8601String(),
        'mime': mime,
        'utType': utType,
        'soloLectura': soloLectura,
        'raiz': raiz.aJson(),
      };

  factory EntradaArchivo.desdeJson(Map<String, Object?> json) {
    final raizJson = json['raiz'];
    return EntradaArchivo(
      nombre: json['nombre'] as String? ?? 'Archivo',
      referencia: json['referencia'] as String? ?? '',
      esCarpeta: json['esCarpeta'] as bool? ?? false,
      origen: OrigenArchivo.values.firstWhere(
        (o) => o.name == json['origen'],
        orElse: () => OrigenArchivo.privado,
      ),
      raiz: raizJson is Map
          ? RaizAutorizada.desdeJson(Map<String, Object?>.from(raizJson))
          : const RaizAutorizada(
              id: 'privado',
              nombre: 'Espacio de la app',
              origen: OrigenArchivo.privado,
              referencia: '',
            ),
      tamano: (json['tamano'] as num?)?.toInt(),
      modificado: DateTime.tryParse(json['modificado'] as String? ?? ''),
      creado: DateTime.tryParse(json['creado'] as String? ?? ''),
      mime: json['mime'] as String?,
      utType: json['utType'] as String?,
      soloLectura: json['soloLectura'] as bool? ?? false,
    );
  }
}

/// Contenido listo para el visor.
class ArchivoAbierto {
  const ArchivoAbierto({
    required this.entrada,
    required this.bytes,
    this.texto,
    this.error,
  });

  final EntradaArchivo entrada;
  final Uint8List bytes;
  final String? texto;
  final String? error;
}
