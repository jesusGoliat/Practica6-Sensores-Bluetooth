import 'package:flutter_test/flutter_test.dart';
import 'package:juego_pares/dominio/carta.dart';
import 'package:juego_pares/dominio/partida_red.dart';

/// Ayudas: pares y un par de índices distintos que no coinciden.
List<List<int>> parejas(SesionPartidaRed s) {
  final m = <String, List<int>>{};
  for (var i = 0; i < s.tablero.length; i++) {
    m.putIfAbsent(s.tablero[i].simboloId, () => []).add(i);
  }
  return m.values.toList();
}

SesionPartidaRed nueva({RolRed rol = RolRed.anfitrion, int semilla = 42}) =>
    SesionPartidaRed.nueva(rol: rol, idPartida: 'a1b2c3d4', semilla: semilla);

/// Jugada con el seq siguiente del jugador.
ResultadoJugadaRed juega(SesionPartidaRed s, RolRed j, int i) =>
    s.aplicarJugada(j, i, s.seqSiguiente(j));

void main() {
  test('la semilla produce el mismo tablero en ambos extremos', () {
    final a = nueva(rol: RolRed.anfitrion);
    final b = nueva(rol: RolRed.invitado);
    expect([for (final c in a.tablero) c.simboloId], [for (final c in b.tablero) c.simboloId]);
    final otra = nueva(semilla: 43);
    expect([for (final c in otra.tablero) c.simboloId],
        isNot([for (final c in a.tablero) c.simboloId]));
    expect(a.tablero.length, 16);
  });

  test('acierto conserva el turno y suma; fallo pasa el turno', () {
    final s = nueva();
    final p = parejas(s);
    expect(s.turno, RolRed.anfitrion);
    expect(juega(s, RolRed.anfitrion, p[0][0]).esPrimera, isTrue);
    final r = juega(s, RolRed.anfitrion, p[0][1]);
    expect(r.acierto, isTrue);
    expect(s.turno, RolRed.anfitrion);
    expect(s.puntos[RolRed.anfitrion], 1);

    juega(s, RolRed.anfitrion, p[1][0]);
    final f = juega(s, RolRed.anfitrion, p[2][0]);
    expect(f.aceptada && !f.acierto, isTrue);
    expect(s.turno, RolRed.invitado);
    expect(s.esperandoOcultar, isTrue);
    // Mientras esperan ocultarse nadie puede jugar.
    expect(juega(s, RolRed.invitado, p[3][0]).esRechazada, isTrue);
    s.ocultarPendientes();
    expect(s.esperandoOcultar, isFalse);
    expect(juega(s, RolRed.invitado, p[3][0]).aceptada, isTrue);
  });

  test('fuera de turno, índice inválido y carta repetida se rechazan', () {
    final s = nueva();
    final p = parejas(s);
    final turno = s.aplicarJugada(RolRed.invitado, p[0][0], 1);
    expect(turno.esRechazada, isTrue);
    expect(turno.codigo, 'turno');
    expect(s.jugadas, isEmpty);
    expect(s.aplicarJugada(RolRed.anfitrion, 99, 1).codigo, 'jugada');
    expect(s.aplicarJugada(RolRed.anfitrion, -1, 1).esRechazada, isTrue);
    juega(s, RolRed.anfitrion, p[0][0]);
    final repetida = s.aplicarJugada(RolRed.anfitrion, p[0][0], 2);
    expect(repetida.esRechazada, isTrue);
    expect(s.ultimoSeq[RolRed.anfitrion], 1);
  });

  test('un seq repetido se ignora y no reaplica la jugada', () {
    final s = nueva();
    final p = parejas(s);
    expect(s.aplicarJugada(RolRed.anfitrion, p[0][0], 1).aceptada, isTrue);
    final dup = s.aplicarJugada(RolRed.anfitrion, p[0][0], 1);
    expect(dup.esDuplicada, isTrue);
    expect(identical(dup, ResultadoJugadaRed.duplicada), isTrue);
    expect(s.jugadas.length, 1);
    expect(s.aplicarJugada(RolRed.anfitrion, p[0][1], 2).acierto, isTrue);
    expect(s.aplicarJugada(RolRed.anfitrion, p[0][1], 2).esDuplicada, isTrue);
    expect(s.puntos[RolRed.anfitrion], 1);
  });

  test('partida completa: gana el anfitrión, empate y estado terminada', () {
    final s = nueva();
    for (final par in parejas(s)) {
      juega(s, RolRed.anfitrion, par[0]);
      final r = juega(s, RolRed.anfitrion, par[1]);
      expect(r.acierto, isTrue);
    }
    expect(s.estado, EstadoSesionRed.terminada);
    expect(s.resultado, 'anfitrion');
    expect(s.puntos[RolRed.anfitrion], 8);
    expect(juega(s, RolRed.anfitrion, 0).esRechazada, isTrue);

    // Empate 4-4.
    final e = nueva(semilla: 5);
    final ps = parejas(e);
    for (var k = 0; k < ps.length; k++) {
      final quien = k < 4 ? RolRed.anfitrion : RolRed.invitado;
      if (k == 4) {
        // Pasar el turno con un fallo no consume parejas.
        final fallo = [ps[4][0], ps[5][0]];
        juega(e, RolRed.anfitrion, fallo[0]);
        juega(e, RolRed.anfitrion, fallo[1]);
        e.ocultarPendientes();
      }
      juega(e, quien, ps[k][0]);
      juega(e, quien, ps[k][1]);
    }
    expect(e.estado, EstadoSesionRed.terminada);
    expect(e.resultado, 'empate');
  });

  test('instantánea ida y vuelta conserva todo el estado', () {
    final s = nueva();
    final p = parejas(s);
    juega(s, RolRed.anfitrion, p[0][0]);
    juega(s, RolRed.anfitrion, p[0][1]);
    juega(s, RolRed.anfitrion, p[1][0]);
    juega(s, RolRed.anfitrion, p[2][0]);
    s.ocultarPendientes();
    juega(s, RolRed.invitado, p[3][0]);
    s.pausarPorDesconexion();

    final r = SesionPartidaRed.desdeJson(s.toJson());
    expect(r.idPartida, s.idPartida);
    expect(r.semilla, s.semilla);
    expect(r.turno, s.turno);
    expect(r.puntos, s.puntos);
    expect(r.ultimoSeq, s.ultimoSeq);
    expect(r.estado, EstadoSesionRed.pausadaPorDesconexion);
    expect(r.rol, RolRed.anfitrion);
    expect([for (final c in r.tablero) c.estado], [for (final c in s.tablero) c.estado]);
    expect(r.toJson()['jugadas'], s.toJson()['jugadas']);
    // Con rol cambiado (invitado recibe la del anfitrión).
    expect(SesionPartidaRed.desdeJson(s.toJson(), rol: RolRed.invitado).rol, RolRed.invitado);
  });

  test('instantánea manipulada se rechaza', () {
    final s = nueva();
    final p = parejas(s);
    juega(s, RolRed.anfitrion, p[0][0]);
    final j = s.toJson();
    (j['jugadas'] as List).add({'j': 'invitado', 'i': 3, 's': 1});
    expect(() => SesionPartidaRed.desdeJson(j), throwsFormatException);
    expect(() => SesionPartidaRed.desdeJson({'x': 1}), throwsFormatException);
  });

  test('REANUDAR: estado, desconocida y terminada', () {
    final s = nueva();
    expect(s.procesarReanudar('a1b2c3d4', 0), ResultadoReanudar.enviarEstado);
    expect(s.procesarReanudar('ffffffff', 0), ResultadoReanudar.sesionDesconocida);
    // El invitado atrasado se pone al día con la instantánea del anfitrión.
    final p = parejas(s);
    final inv = nueva(rol: RolRed.invitado);
    juega(s, RolRed.anfitrion, p[0][0]);
    juega(s, RolRed.anfitrion, p[0][1]);
    expect(inv.totalJugadas, 0);
    final puesto = SesionPartidaRed.desdeJson(s.toJson(), rol: RolRed.invitado);
    expect(puesto.totalJugadas, 2);
    expect(puesto.puntos[RolRed.anfitrion], 1);
    for (final par in parejas(s).skip(1)) {
      juega(s, RolRed.anfitrion, par[0]);
      juega(s, RolRed.anfitrion, par[1]);
    }
    expect(s.procesarReanudar('a1b2c3d4', 2), ResultadoReanudar.partidaTerminada);
    // Una jugada repetida tras reanudar sigue ignorándose.
    expect(puesto.aplicarJugada(RolRed.anfitrion, p[0][1], 2).esDuplicada, isTrue);
  });

  test('abandono y niveles', () {
    final s = nueva();
    s.abandonar();
    expect(s.estado, EstadoSesionRed.abandonada);
    expect(s.descripcionResultado(), contains('abandonada'));
    expect(normalizarNivelRed('4x4'), 'campus');
    expect(normalizarNivelRed('x'), isNull);
    expect(SesionPartidaRed.nueva(rol: RolRed.anfitrion, nivel: 'laboratorio', semilla: 1).tablero.length, 36);
    expect(s.tablero.every((c) => c.estado == EstadoCarta.oculta), isTrue);
  });
}
