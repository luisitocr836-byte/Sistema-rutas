import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/tema.dart';
import '../estado/datos_modelo.dart';
import '../servicios/proveedor_datos.dart';
import '../widgets/comunes.dart';
import '../widgets/mapa_ruta.dart';
import '../widgets/panel_seguimiento.dart';
import '../widgets/tarjeta_ruta.dart';

/// Seguimiento de una ruta: mapa con la unidad y panel con el ETA a la siguiente parada.
class PantallaSeguimiento extends StatefulWidget {
  final String? numeroRutaInicial;
  const PantallaSeguimiento({super.key, this.numeroRutaInicial});

  @override
  State<PantallaSeguimiento> createState() => _PantallaSeguimientoState();
}

class _PantallaSeguimientoState extends State<PantallaSeguimiento> {
  String? _numero;

  @override
  void initState() {
    super.initState();
    _numero = widget.numeroRutaInicial;
  }

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosModelo>();
    final rp = (_numero != null ? datos.rutaPorNumero(_numero!) : null) ?? (datos.rutas.isEmpty ? null : datos.rutas.first);
    final unidad = rp == null ? null : datos.unidadDeRuta(rp.ruta.idRuta);
    final est = unidad == null ? null : datos.estimaciones[unidad.idUnidad];

    return PantallaBase(
      titulo: 'Seguimiento',
      conVolver: Navigator.of(context).canPop(),
      alActualizar: datos.recargar,
      hijos: [
        if (datos.cargando && datos.rutas.isEmpty)
          const EstadoCarga('Cargando…')
        else if (datos.error != null && datos.rutas.isEmpty)
          EstadoError(mensaje: datos.error!, alReintentar: datos.recargar)
        else if (rp == null)
          const EstadoVacio('No hay rutas disponibles.')
        else ...[
          Wrap(spacing: 8, children: [
            for (final r in datos.rutas)
              ChoiceChip(
                label: Text('Ruta ${r.ruta.numeroRuta}'),
                selected: r.ruta.numeroRuta == rp.ruta.numeroRuta,
                onSelected: (_) => setState(() => _numero = r.ruta.numeroRuta),
              ),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              datos.modo == ModoDatos.local ? 'Modo demostración: unidades simuladas' : 'Conexión en vivo: ${datos.estadoRealtime.name}',
              style: const TextStyle(color: Colores.atenuado, fontSize: 11),
            ),
          ),
          const SizedBox(height: 10),
          MapaRuta(rutas: [rp], unidades: datos.unidades, altura: 280, idParadaObjetivo: est?.idParadaObjetivo),
          const SizedBox(height: 14),
          PanelSeguimiento(rutaConParadas: rp),
          const SizedBox(height: 16),
          const Text('Paradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ListaParadas(paradas: rp.paradas, idParadaObjetivo: est?.idParadaObjetivo, color: colorDeHex(rp.ruta.colorHex)),
        ],
      ],
    );
  }
}
