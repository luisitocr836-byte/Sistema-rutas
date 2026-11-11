import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/tema.dart';
import '../core/core.dart';
import '../estado/datos_modelo.dart';
import '../utilidades/formato.dart';
import '../widgets/comunes.dart';

class PantallaIncidencias extends StatelessWidget {
  const PantallaIncidencias({super.key});

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosModelo>();
    final porId = {for (final r in datos.rutas) r.ruta.idRuta: r.ruta};

    return PantallaBase(
      titulo: 'Incidencias viales',
      conVolver: true,
      alActualizar: datos.recargar,
      hijos: [
        if (datos.cargando && datos.incidencias.isEmpty)
          const EstadoCarga('Cargando incidencias…')
        else if (datos.error != null && datos.incidencias.isEmpty)
          EstadoError(mensaje: datos.error!, alReintentar: datos.recargar)
        else if (datos.incidencias.isEmpty)
          const EstadoVacio('Sin incidencias activas registradas.')
        else
          for (final i in datos.incidencias)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colores.panel, border: Border.all(color: Colores.linea), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(i.tipoIncidencia.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colores.alerta))),
                  if (i.fuenteDatos == FuenteDatos.demostracion) const InsigniaDato(TipoDato.demostracion),
                ]),
                const SizedBox(height: 6),
                Text(i.descripcion),
                const SizedBox(height: 6),
                Text(
                  [
                    if (i.idRutaAfectada != null && porId[i.idRutaAfectada] != null) 'Ruta ${porId[i.idRutaAfectada]!.numeroRuta}',
                    if (i.retrasoEstimadoMin != null) 'Retraso estimado: ${formatearMinutos(i.retrasoEstimadoMin!)}',
                  ].join(' · '),
                  style: const TextStyle(color: Colores.atenuado, fontSize: 12),
                ),
              ]),
            ),
      ],
    );
  }
}
