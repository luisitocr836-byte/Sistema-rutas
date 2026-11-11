import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/tema.dart';
import '../core/core.dart';
import '../servicios/favoritos.dart';
import 'comunes.dart';

/// Botón de favorito (☆/★) con persistencia y aviso si no se pudo guardar.
class BotonFavorito extends StatelessWidget {
  final String numeroRuta;
  const BotonFavorito({super.key, required this.numeroRuta});

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<Favoritos>();
    final esFav = fav.esFavorita(numeroRuta);
    return IconButton(
      tooltip: esFav ? 'Quitar de favoritos' : 'Guardar en favoritos',
      icon: Icon(esFav ? Icons.star : Icons.star_border, color: esFav ? Colores.favorito : Colores.atenuado),
      onPressed: () async {
        final error = await context.read<Favoritos>().alternar(numeroRuta);
        if (!context.mounted) return;
        mostrarAviso(context, error ?? (esFav ? 'Ruta $numeroRuta quitada de favoritos' : 'Ruta $numeroRuta guardada en favoritos'));
      },
    );
  }
}

class TarjetaRuta extends StatelessWidget {
  final Ruta ruta;
  final VoidCallback alAbrir;
  const TarjetaRuta({super.key, required this.ruta, required this.alAbrir});

  @override
  Widget build(BuildContext context) {
    final color = colorDeHex(ruta.colorHex);
    return Material(
      color: Colores.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: alAbrir,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          decoration: BoxDecoration(border: Border.all(color: Colores.linea), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Text(ruta.numeroRuta, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ruta.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Text('${ruta.origen} → ${ruta.destino}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colores.atenuado, fontSize: 12)),
                if (ruta.fuenteDatos == FuenteDatos.demostracion) ...[
                  const SizedBox(height: 6),
                  const InsigniaDato(TipoDato.demostracion),
                ],
              ]),
            ),
            BotonFavorito(numeroRuta: ruta.numeroRuta),
          ]),
        ),
      ),
    );
  }
}

class ListaParadas extends StatelessWidget {
  final List<Parada> paradas;
  final int? idParadaObjetivo;
  final Color color;
  const ListaParadas({super.key, required this.paradas, this.idParadaObjetivo, required this.color});

  @override
  Widget build(BuildContext context) {
    final ordenadas = [...paradas]..sort((a, b) => a.ordenSecuencia.compareTo(b.ordenSecuencia));
    return Column(children: [
      for (final p in ordenadas)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.idParada == idParadaObjetivo ? Colores.cajaInfo : Colores.panel,
            border: Border.all(color: p.idParada == idParadaObjetivo ? Colores.azul : Colores.linea),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            CircleAvatar(radius: 13, backgroundColor: color, child: Text('${p.ordenSecuencia}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (p.referenciaVial != null) Text(p.referenciaVial!, style: const TextStyle(color: Colores.atenuado, fontSize: 11)),
              ]),
            ),
            if (p.esNodoTransferencia) const Tooltip(message: 'Nodo de transferencia', child: Icon(Icons.swap_horiz, color: Colores.favorito, size: 18)),
            if (p.idParada == idParadaObjetivo) const Padding(padding: EdgeInsets.only(left: 6), child: Text('Siguiente', style: TextStyle(color: Colores.azul, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
        ),
    ]);
  }
}
