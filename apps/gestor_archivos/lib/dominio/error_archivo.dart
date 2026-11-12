import 'dart:io';

import 'package:saf/saf.dart';

/// Errores de archivo con un mensaje legible para el usuario.
enum TipoErrorArchivo {
  noEncontrado,
  sinPermiso,
  noEsCarpeta,
  lectura,
  escritura,
  espacio,
  nombreInvalido,
  destinoNoAutorizado,
  noSoportado,
  conflicto,
  corrupto,
  desconocido,
}

class ErrorArchivo implements Exception {
  const ErrorArchivo(this.tipo, this.mensaje, {this.causa});

  final TipoErrorArchivo tipo;
  final String mensaje;
  final Object? causa;

  /// Traduce excepciones de dart:io, SAF y plugins a algo que se pueda mostrar.
  factory ErrorArchivo.desde(Object error) {
    if (error is ErrorArchivo) return error;
    if (error is SafPermissionException) {
      return ErrorArchivo(
        TipoErrorArchivo.sinPermiso,
        'El proveedor de documentos no permite esta operación. Vuelve a autorizar la carpeta o importa el archivo al espacio de la app.',
        causa: error,
      );
    }
    if (error is SafNotFoundException) {
      return ErrorArchivo(
        TipoErrorArchivo.noEncontrado,
        'El archivo o la carpeta ya no existe.',
        causa: error,
      );
    }
    if (error is SafAlreadyExistsException) {
      return ErrorArchivo(
        TipoErrorArchivo.conflicto,
        'Ya existe un archivo con ese nombre en la carpeta de destino.',
        causa: error,
      );
    }
    if (error is SafIoException) {
      return ErrorArchivo(
        TipoErrorArchivo.escritura,
        'El proveedor de documentos no pudo completar la operación.',
        causa: error,
      );
    }
    if (error is FileSystemException) {
      final codigo = error.osError?.errorCode;
      if (codigo == 28) {
        return ErrorArchivo(
          TipoErrorArchivo.espacio,
          'No hay espacio suficiente para guardar el archivo.',
          causa: error,
        );
      }
      final mensaje = (error.message.isEmpty ? 'No se pudo acceder al archivo.' : error.message);
      if (mensaje.toLowerCase().contains('permission') ||
          mensaje.toLowerCase().contains('denied') ||
          mensaje.toLowerCase().contains('operation not permitted')) {
        return ErrorArchivo(
          TipoErrorArchivo.sinPermiso,
          'El sistema no permite acceder a esa ubicación.',
          causa: error,
        );
      }
      if (error.osError?.errorCode == 2) {
        return ErrorArchivo(
          TipoErrorArchivo.noEncontrado,
          'El archivo o la carpeta ya no existe.',
          causa: error,
        );
      }
      return ErrorArchivo(TipoErrorArchivo.escritura, mensaje, causa: error);
    }
    if (error is FormatException) {
      return ErrorArchivo(
        TipoErrorArchivo.corrupto,
        'El archivo está incompleto o tiene un formato inválido.',
        causa: error,
      );
    }
    return ErrorArchivo(
      TipoErrorArchivo.desconocido,
      'Ocurrió un error inesperado: $error',
      causa: error,
    );
  }

  @override
  String toString() => mensaje;
}
