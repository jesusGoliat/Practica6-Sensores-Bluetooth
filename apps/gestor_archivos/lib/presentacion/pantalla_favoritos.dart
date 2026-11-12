import 'package:comun/comun.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../datos/estado_gestor.dart';
import 'widgets/lista_guardados.dart';

class PantallaFavoritos extends StatelessWidget {
  const PantallaFavoritos({super.key});

  @override
  Widget build(BuildContext context) {
    final gestor = context.watch<EstadoGestor>();
    if (gestor.favoritos.isEmpty) {
      return const EstadoVacio(
        icono: Icons.star_border,
        titulo: T.sinFavoritos,
        mensaje: 'Marca archivos o carpetas con la estrella desde el explorador y aparecerán aquí.',
      );
    }
    return ListaGuardados(
      entradas: gestor.favoritos,
      textoQuitar: 'Quitar de favoritos',
      alQuitar: (entrada) => gestor.quitarFavorito(entrada),
    );
  }
}
