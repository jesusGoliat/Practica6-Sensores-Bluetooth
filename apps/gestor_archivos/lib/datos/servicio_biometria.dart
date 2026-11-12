import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum TipoResultadoAutenticacion { exito, cancelado, fallido, noDisponible, sinBloqueo }

/// Resultado de pedir identidad al sistema. Solo `exito` autoriza.
class ResultadoAutenticacion {
  const ResultadoAutenticacion._(this.tipo, [this.mensaje]);

  static const exito = ResultadoAutenticacion._(TipoResultadoAutenticacion.exito);
  static const cancelado = ResultadoAutenticacion._(
      TipoResultadoAutenticacion.cancelado, 'Autenticación cancelada. No se realizó ningún cambio.');
  static const fallido = ResultadoAutenticacion._(TipoResultadoAutenticacion.fallido,
      'No se pudo verificar tu identidad. No se realizó ningún cambio.');
  static const sinBloqueo = ResultadoAutenticacion._(TipoResultadoAutenticacion.sinBloqueo,
      'Este dispositivo no tiene bloqueo de pantalla ni biometría configurados. '
      'Configura un PIN, patrón o huella en los ajustes del sistema para usar esta función.');

  factory ResultadoAutenticacion.noDisponible(String motivo) =>
      ResultadoAutenticacion._(TipoResultadoAutenticacion.noDisponible, motivo);

  final TipoResultadoAutenticacion tipo;
  final String? mensaje;

  bool get esExito => tipo == TipoResultadoAutenticacion.exito;

  /// Texto para mostrar al usuario cuando no hubo éxito.
  String get explicacion => mensaje ?? '';

  @override
  bool operator ==(Object other) =>
      other is ResultadoAutenticacion && other.tipo == tipo && other.mensaje == mensaje;

  @override
  int get hashCode => Object.hash(tipo, mensaje);

  @override
  String toString() => 'ResultadoAutenticacion($tipo, $mensaje)';
}

/// Contrato inyectable (los tests usan un falso).
abstract interface class Autenticador {
  Future<ResultadoAutenticacion> autenticar(String motivo);
}

/// Envuelve `local_auth`. `biometricOnly: false` permite PIN/patrón del sistema.
/// La app nunca recibe la huella: solo un sí/no del sistema.
class ServicioBiometria implements Autenticador {
  ServicioBiometria({LocalAuthentication? local}) : _local = local ?? LocalAuthentication();

  final LocalAuthentication _local;

  @override
  Future<ResultadoAutenticacion> autenticar(String motivo) async {
    try {
      final soportado = await _local.isDeviceSupported();
      if (!soportado) return ResultadoAutenticacion.sinBloqueo;
      final ok = await _local.authenticate(
        localizedReason: motivo,
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      );
      return ok ? ResultadoAutenticacion.exito : ResultadoAutenticacion.fallido;
    } on LocalAuthException catch (e) {
      return _desdeCodigo(e.code);
    } on PlatformException catch (e) {
      return _desdeTexto(e.code);
    } catch (_) {
      return ResultadoAutenticacion.noDisponible(
          'No se pudo usar la autenticación del sistema en este dispositivo.');
    }
  }

  static ResultadoAutenticacion _desdeCodigo(LocalAuthExceptionCode c) => switch (c) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.userRequestedFallback =>
          ResultadoAutenticacion.cancelado,
        LocalAuthExceptionCode.noCredentialsSet => ResultadoAutenticacion.sinBloqueo,
        LocalAuthExceptionCode.noBiometricsEnrolled => ResultadoAutenticacion.noDisponible(
            'No hay huella ni rostro registrados. Registra uno o configura un PIN en el sistema.'),
        LocalAuthExceptionCode.noBiometricHardware => ResultadoAutenticacion.noDisponible(
            'Este dispositivo no tiene sensor biométrico; se usará la credencial del dispositivo si existe.'),
        LocalAuthExceptionCode.temporaryLockout => ResultadoAutenticacion.noDisponible(
            'Demasiados intentos. Espera un momento antes de volver a intentar.'),
        LocalAuthExceptionCode.biometricLockout => ResultadoAutenticacion.noDisponible(
            'Biometría bloqueada por demasiados intentos. Usa tu PIN o patrón del dispositivo.'),
        LocalAuthExceptionCode.timeout => ResultadoAutenticacion.cancelado,
        _ => ResultadoAutenticacion.noDisponible(
            'La autenticación no está disponible en este momento.'),
      };

  static ResultadoAutenticacion _desdeTexto(String codigo) => switch (codigo) {
        'NotAvailable' => ResultadoAutenticacion.noDisponible(
            'La autenticación biométrica no está disponible en este dispositivo.'),
        'NotEnrolled' => ResultadoAutenticacion.noDisponible(
            'No hay huella ni rostro registrados en el dispositivo.'),
        'PasscodeNotSet' => ResultadoAutenticacion.sinBloqueo,
        'LockedOut' => ResultadoAutenticacion.noDisponible(
            'Demasiados intentos fallidos. Espera un momento e inténtalo de nuevo.'),
        'PermanentlyLockedOut' => ResultadoAutenticacion.noDisponible(
            'La biometría está bloqueada. Desbloquea el dispositivo con tu PIN o patrón.'),
        _ => ResultadoAutenticacion.fallido,
      };
}
