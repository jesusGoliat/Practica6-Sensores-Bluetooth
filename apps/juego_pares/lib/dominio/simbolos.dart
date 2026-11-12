import 'package:flutter/material.dart';

/// Categorías temáticas del memorama. Cada pareja pertenece a una categoría y
/// completarla otorga una bonificación extra.
enum Categoria { ciencias, ingenieria, computo, ipn }

extension CategoriaInfo on Categoria {
  String get etiqueta => switch (this) {
        Categoria.ciencias => 'Ciencias',
        Categoria.ingenieria => 'Ingeniería',
        Categoria.computo => 'Cómputo',
        Categoria.ipn => 'IPN',
      };

  Color get color => switch (this) {
        Categoria.ciencias => const Color(0xFF2E7D32),
        Categoria.ingenieria => const Color(0xFFEF6C00),
        Categoria.computo => const Color(0xFF003B5C),
        Categoria.ipn => const Color(0xFF6C1D45),
      };

  IconData get icono => switch (this) {
        Categoria.ciencias => Icons.science_outlined,
        Categoria.ingenieria => Icons.precision_manufacturing_outlined,
        Categoria.computo => Icons.computer_outlined,
        Categoria.ipn => Icons.school_outlined,
      };
}

/// Símbolo disponible en el tablero. El icono se resuelve en la UI para no
/// guardar datos de presentación dentro del archivo de partida.
class Simbolo {
  const Simbolo(this.id, this.etiqueta, this.categoria);
  final String id;
  final String etiqueta;
  final Categoria categoria;

  IconData get icono => switch (id) {
    'chip' => Icons.memory,
    'monitor' => Icons.monitor,
    'libro' => Icons.menu_book,
    'microscopio' => Icons.biotech,
    'engrane' => Icons.settings,
    'red' => Icons.hub,
    'nube' => Icons.cloud_queue,
    'escudo' => Icons.security,
    'bombilla' => Icons.lightbulb_outline,
    'cohete' => Icons.rocket_launch_outlined,
    'planeta' => Icons.public,
    'adn' => Icons.psychology_alt_outlined,
    'robot' => Icons.smart_toy_outlined,
    'satelite' => Icons.satellite_alt_outlined,
    'grafica' => Icons.insights,
    'llave' => Icons.vpn_key_outlined,
    'trofeo' => Icons.emoji_events_outlined,
    'escuela' => Icons.account_balance_outlined,
    _ => Icons.help_outline,
  };
}

const List<Simbolo> simbolosDisponibles = <Simbolo>[
  Simbolo('chip', 'Chip', Categoria.computo),
  Simbolo('monitor', 'Monitor', Categoria.computo),
  Simbolo('red', 'Red', Categoria.computo),
  Simbolo('robot', 'Robot', Categoria.computo),
  Simbolo('grafica', 'Gráfica', Categoria.computo),
  Simbolo('engrane', 'Engrane', Categoria.ingenieria),
  Simbolo('bombilla', 'Bombilla', Categoria.ingenieria),
  Simbolo('cohete', 'Cohete', Categoria.ingenieria),
  Simbolo('satelite', 'Satélite', Categoria.ingenieria),
  Simbolo('llave', 'Llave', Categoria.ingenieria),
  Simbolo('microscopio', 'Microscopio', Categoria.ciencias),
  Simbolo('planeta', 'Planeta', Categoria.ciencias),
  Simbolo('adn', 'ADN', Categoria.ciencias),
  Simbolo('nube', 'Nube', Categoria.ciencias),
  Simbolo('libro', 'Libro', Categoria.ipn),
  Simbolo('escudo', 'Escudo', Categoria.ipn),
  Simbolo('trofeo', 'Trofeo', Categoria.ipn),
  Simbolo('escuela', 'Escuela', Categoria.ipn),
];

Simbolo simboloPorId(String id) =>
    simbolosDisponibles.firstWhere((s) => s.id == id, orElse: () => simbolosDisponibles.first);
