import 'dart:async';
import 'dart:io';

import 'package:enlace_ble/enlace_ble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juego_pares/datos/estado_partida_red.dart';
import 'package:juego_pares/datos/puente_ble.dart';
import 'package:juego_pares/datos/repositorio_partida_red.dart';
import 'package:juego_pares/dominio/partida_red.dart';

/// "Aire" compartido entre dos puentes en memoria.
class RedMemoria {
  final conexiones = StreamController<TransporteBytes>.broadcast();
  bool anunciando = false;
  TransporteMemoria? actual;
}

class PuenteMemoria implements PuenteBle {
  PuenteMemoria(this.red);
  final RedMemoria red;
  EstadoBluetooth estadoBt = EstadoBluetooth.encendido;

  @override
  Future<EstadoBluetooth> iniciarAnuncio() async {
    if (estadoBt.disponible) red.anunciando = true;
    return estadoBt;
  }

  @override
  bool get anunciando => red.anunciando;
  @override
  String? get mensajeError => null;
  @override
  String? get nombreAnuncio => 'P6-juego-test';
  @override
  Stream<TransporteBytes> get conexiones => red.conexiones.stream;
  @override
  Future<void> detenerAnuncio() async => red.anunciando = false;
  @override
  Future<EstadoBluetooth> permisosInvitado() async => estadoBt;
  @override
  Stream<DispositivoEncontrado> escanear() => red.anunciando
      ? Stream.value(const DispositivoEncontrado(id: 'd1', nombre: 'P6-juego-test', rssi: -50))
      : const Stream.empty();
  @override
  Future<TransporteBytes?> conectar(String id) async {
    if (!red.anunciando) return null;
    final (a, b) = TransporteMemoria.par(maxFragmento: 200);
    red.actual = a;
    red.anunciando = false;
    red.conexiones.add(a);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    return b;
  }

  @override
  String? get mensajeErrorCliente => null;
  @override
  Future<void> abrirAjustes() async {}
  @override
  Future<void> liberar() async {}
}

Future<void> asentar() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

List<List<int>> parejas(SesionPartidaRed s) {
  final m = <String, List<int>>{};
  for (var i = 0; i < s.tablero.length; i++) {
    m.putIfAbsent(s.tablero[i].simboloId, () => []).add(i);
  }
  return m.values.toList();
}

void main() {
  late Directory dirH, dirG;
  late RedMemoria red;
  late EstadoPartidaRed host, guest;

  EstadoPartidaRed crear(RedMemoria r, Directory d, String nombre) => EstadoPartidaRed(
        puente: PuenteMemoria(r),
        repositorio: RepositorioPartidaRed.enDirectorio(d),
        nombreLocal: nombre,
        retardoOcultar: const Duration(milliseconds: 5),
        tiempoAck: const Duration(milliseconds: 300),
        reintentosAck: 1,
      );

  Future<void> emparejar() async {
    await host.iniciarAnfitrion();
    await guest.iniciarInvitado();
    await asentar();
    await guest.conectarCon(guest.dispositivos.first);
    await asentar();
    await host.responderSolicitud(true);
    await asentar();
  }

  /// Quien tenga el turno voltea una pareja completa.
  Future<void> jugarPar(List<int> par) async {
    final quien = host.sesion!.esMiTurno ? host : guest;
    await quien.jugarLocal(par[0]);
    await asentar();
    await quien.jugarLocal(par[1]);
    await asentar();
  }

  setUp(() {
    dirH = Directory.systemTemp.createTempSync('red-h-');
    dirG = Directory.systemTemp.createTempSync('red-g-');
    red = RedMemoria();
    host = crear(red, dirH, 'Ana');
    guest = crear(red, dirG, 'Beto');
  });

  tearDown(() {
    host.dispose();
    guest.dispose();
    dirH.deleteSync(recursive: true);
    dirG.deleteSync(recursive: true);
  });

  test('handshake, partida corta con duplicado, desconexión y reanudación', () async {
    await emparejar();
    expect(host.solicitud, isNull);
    expect(host.nombreRival, 'Beto');
    final h = host.sesion!, g = guest.sesion!;
    expect(h.idPartida, g.idPartida);
    expect([for (final c in h.tablero) c.simboloId], [for (final c in g.tablero) c.simboloId]);
    expect(h.esMiTurno, isTrue);
    expect(g.esMiTurno, isFalse);

    final p = parejas(h);
    // Acierto del anfitrión: conserva el turno.
    await host.jugarLocal(p[0][0]);
    await asentar();
    await host.jugarLocal(p[0][1]);
    await asentar();
    expect(g.puntos[RolRed.anfitrion], 1);
    expect(h.turno, RolRed.anfitrion);
    expect(g.turno, RolRed.anfitrion);

    // Fuera de turno: el invitado no puede jugar.
    await guest.jugarLocal(p[1][0]);
    expect(guest.aviso, 'No es tu turno');
    expect(h.totalJugadas, 2);

    // Fallo del anfitrión: pasa el turno y se ocultan las cartas.
    await host.jugarLocal(p[1][0]);
    await asentar();
    await host.jugarLocal(p[2][0]);
    await asentar();
    expect(h.turno, RolRed.invitado);
    expect(g.turno, RolRed.invitado);
    expect(h.esperandoOcultar, isFalse);
    expect(g.esperandoOcultar, isFalse);

    // JUGADA duplicada (mismo seq): el anfitrión la ignora una sola vez.
    await guest.jugarLocal(p[3][0]);
    await asentar();
    final antes = h.totalJugadas;
    await guest.reenviarUltimaJugada();
    await asentar();
    expect(h.totalJugadas, antes);
    expect(host.registro.any((l) => l.contains('Mensaje duplicado ignorado (seq')), isTrue);
    expect(host.aviso, startsWith('Mensaje duplicado ignorado'));
    await guest.jugarLocal(p[3][1]);
    await asentar();
    expect(h.puntos[RolRed.invitado], 1);
    expect(g.puntos[RolRed.invitado], 1);

    // Desconexión: ambos pausan y guardan.
    red.actual!.simularDesconexion();
    await asentar();
    expect(h.estado, EstadoSesionRed.pausadaPorDesconexion);
    expect(g.estado, EstadoSesionRed.pausadaPorDesconexion);
    expect(File('${dirH.path}/partida_red.json').existsSync(), isTrue);
    await guest.jugarLocal(p[4][0]);
    expect(guest.aviso, isNotNull);
    expect(g.totalJugadas, h.totalJugadas);

    // Reconexión con REANUDAR / ESTADO.
    await host.reintentarConexion();
    await guest.reintentarConexion();
    await asentar();
    expect(host.sesion!.estado, EstadoSesionRed.enJuego);
    expect(guest.sesion!.estado, EstadoSesionRed.enJuego);
    expect(guest.sesion!.totalJugadas, host.sesion!.totalJugadas);
    expect(guest.registro.any((l) => l.contains('Estado del anfitrión recibido')), isTrue);

    // Se termina la partida sin jugadas repetidas.
    for (var k = 0; k < p.length; k++) {
      if (k == 0 || k == 3) continue; // ya emparejadas
      await jugarPar(p[k]);
    }
    expect(host.sesion!.estado, EstadoSesionRed.terminada);
    expect(guest.sesion!.estado, EstadoSesionRed.terminada);
    expect(host.sesion!.resultado, guest.sesion!.resultado);
    expect(host.sesion!.puntos, guest.sesion!.puntos);
    expect(host.sesion!.puntos.values.reduce((a, b) => a + b), 8);
  });

  test('recupera la partida guardada tras reiniciar la app', () async {
    await emparejar();
    final p = parejas(host.sesion!);
    await host.jugarLocal(p[0][0]);
    await asentar();
    await host.jugarLocal(p[0][1]);
    await asentar();
    final id = host.sesion!.idPartida;
    host.dispose();
    guest.dispose();
    // Marcadores para el tearDown.
    host = crear(RedMemoria(), dirH, 'x');
    guest = crear(RedMemoria(), dirG, 'y');

    final red2 = RedMemoria();
    final host2 = crear(red2, dirH, 'Ana');
    final guest2 = crear(red2, dirG, 'Beto');
    addTearDown(host2.dispose);
    addTearDown(guest2.dispose);
    await host2.cargarPendiente();
    await guest2.cargarPendiente();
    expect(host2.pendiente!.idPartida, id);
    expect(host2.pendiente!.totalJugadas, 2);
    await host2.recuperar();
    await guest2.recuperar();
    await asentar();
    await guest2.conectarCon(guest2.dispositivos.first);
    await asentar();
    expect(host2.sesion!.estado, EstadoSesionRed.enJuego);
    expect(guest2.sesion!.estado, EstadoSesionRed.enJuego);
    expect(guest2.sesion!.puntos[RolRed.anfitrion], 1);
  });

  test('REANUDAR de una partida desconocida termina con FIN', () async {
    await emparejar();
    red.actual!.simularDesconexion();
    await asentar();
    await host.descartarPendiente();
    // El anfitrión olvida la partida (p. ej. la descartó y reinició).
    await host.cancelarRol();
    await host.iniciarAnfitrion();
    await guest.reintentarConexion();
    await asentar();
    expect(guest.sesion!.estado, EstadoSesionRed.terminada);
    expect(guest.sesion!.motivoFin, 'sesion');
    expect(guest.mensajeRival, contains('terminó'));
  });

  test('Salir envía ADIOS y el otro lado marca abandonada', () async {
    await emparejar();
    await guest.salir();
    await asentar();
    expect(guest.sesion, isNull);
    expect(host.sesion!.estado, EstadoSesionRed.abandonada);
    expect(host.mensajeRival, 'El otro jugador salió');
    expect(File('${dirH.path}/partida_red.json').existsSync(), isTrue);
    await host.cerrarPartida();
    expect(host.sesion, isNull);
  });

  test('Bluetooth apagado se informa sin fallar', () async {
    final puente = PuenteMemoria(RedMemoria())..estadoBt = EstadoBluetooth.apagado;
    final e = EstadoPartidaRed(
        puente: puente, repositorio: RepositorioPartidaRed.enDirectorio(dirH));
    addTearDown(e.dispose);
    await e.iniciarAnfitrion();
    expect(e.fase, FaseRed.inicio);
    expect(e.mensajeBt, EstadoBluetooth.apagado.mensaje);
    puente.estadoBt = EstadoBluetooth.permisoDenegadoPermanente;
    await e.iniciarInvitado();
    expect(e.bt, EstadoBluetooth.permisoDenegadoPermanente);
  });
}
