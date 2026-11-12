/// Contrato de transporte de fragmentos ya conectado.
library;

import 'dart:typed_data';

/// Estado de una conexión.
enum EstadoConexion { conectando, conectado, desconectado }

/// Una conexión ya establecida que mueve fragmentos de bytes.
abstract interface class TransporteBytes {
  /// Tamaño máximo (cabecera incluida) de cada fragmento enviado.
  int get maxFragmento;

  /// Fragmentos recibidos del par.
  Stream<Uint8List> get recibidos;

  /// Envía un fragmento. Lanza si la conexión no está activa.
  Future<void> enviar(Uint8List fragmento);

  /// Cambios de estado de la conexión.
  Stream<EstadoConexion> get estado;

  /// Estado actual (adición al contrato: los streams no repiten el último valor).
  EstadoConexion get estadoActual;

  /// Cierra la conexión y libera recursos. Idempotente.
  Future<void> cerrar();
}
