import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../estado/datos_modelo.dart';
import '../servicios/favoritos.dart';
import '../widgets/comunes.dart';
import '../widgets/tarjeta_ruta.dart';
import 'detalle_ruta.dart';

class PantallaFavoritos extends StatelessWidget {
  final VoidCallback irARutas;
  const PantallaFavoritos({super.key, required this.irARutas});

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosModelo>();
    final fav = context.watch<Favoritos>();
    final lista = datos.rutas.where((r) => fav.esFavorita(r.ruta.numeroRuta)).toList();

    return PantallaBase(
      titulo: 'Favoritos',
      alActualizar: datos.recargar,
      hijos: [
        if (!fav.cargado || (datos.cargando && datos.rutas.isEmpty))
          const EstadoCarga('Cargando favoritos…')
        else if (datos.error != null && datos.rutas.isEmpty)
          EstadoError(mensaje: datos.error!, alReintentar: datos.recargar)
        else if (lista.isEmpty)
          EstadoVacio(
            'Aún no tienes rutas favoritas. Explora las rutas y toca ☆ para guardar una.',
            accion: TextButton(onPressed: irARutas, child: const Text('Explorar rutas →')),
          )
        else
          for (final r in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaRuta(
                ruta: r.ruta,
                alAbrir: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PantallaDetalleRuta(numeroRuta: r.ruta.numeroRuta))),
              ),
            ),
      ],
    );
  }
}
