import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/tema.dart';
import '../core/core.dart';
import '../estado/datos_modelo.dart';
import '../utilidades/formato.dart';
import 'comunes.dart';

/// Panel de seguimiento de la unidad de una ruta: estado GPS, velocidad, edad del dato y ETA a la
/// siguiente parada. Nunca muestra un ETA inventado: si falta la estimación lo dice.
class PanelSeguimiento extends StatelessWidget {
  final RutaConParadas rutaConParadas;
  const PanelSeguimiento({super.key, required this.rutaConParadas});

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosModelo>();
    final unidad = datos.unidadDeRuta(rutaConParadas.ruta.idRuta);
    final est = unidad == null ? null : datos.estimaciones[unidad.idUnidad];

    return RelojBuilder(builder: (context, ahora) {
      final estado = estadoDeUnidad(unidad, ahora);
      final edad = segundosDesde(unidad?.ultimaActualizacion, ahora);
      final vigente = estimacionVigente(est, ahora);
      Parada? objetivo;
      if (est != null) {
        for (final p in rutaConParadas.paradas) {
          if (p.idParada == est.idParadaObjetivo) objetivo = p;
        }
      }
      final simulada = unidad?.ultimoOrigenDato == OrigenDato.simulado;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colores.panel, border: Border.all(color: Colores.linea), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Seguimiento de la unidad', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            if (unidad != null && unidad.tienePosicion) InsigniaDato(simulada ? TipoDato.demostracion : TipoDato.real),
          ]),
          const SizedBox(height: 10),
          if (unidad == null)
            const Text('No hay unidades asignadas a esta ruta.', style: TextStyle(color: Colores.atenuado))
          else ...[
            _Fila('Unidad', unidad.numeroEconomico),
            _Fila('Estado', textoEstadoUnidad[estado]!),
            _Fila('Velocidad', formatearKmh(unidad.ultimaVelocidadKmh)),
            _Fila('Última posición', describirEdad(edad)),
            const Divider(height: 22, color: Colores.linea),
            if (est == null || !vigente || estado == EstadoUnidad.sinDatos || estado == EstadoUnidad.sinSenal)
              Text(
                estado == EstadoUnidad.sinDatos
                    ? 'Sin estimación disponible: aún no hay posiciones GPS de esta unidad.'
                    : estado == EstadoUnidad.sinSenal
                        ? 'Sin estimación disponible: la señal GPS no es reciente.'
                        : 'Sin estimación disponible por ahora.',
                style: const TextStyle(color: Colores.alerta),
              )
            else ...[
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatearMinutos(est.etaEstimadoMin), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colores.azul)),
                const SizedBox(width: 10),
                InsigniaDato(est.esSimulado ? TipoDato.demostracion : TipoDato.estimado),
              ]),
              const SizedBox(height: 6),
              Text('hasta ${objetivo?.nombre ?? 'la siguiente parada'} · ${formatearDistancia(est.distanciaRestanteM)}', style: const TextStyle(color: Colores.atenuado, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                'Cálculo: ${est.fuenteCalculo == FuenteCalculo.respaldoRuta ? 'respaldo por trazado' : est.fuenteCalculo.db}'
                '${est.fuenteCalculo == FuenteCalculo.osrm ? ' (sin tráfico en vivo)' : ''}',
                style: const TextStyle(color: Colores.atenuado, fontSize: 11),
              ),
            ],
          ],
        ]),
      );
    });
  }
}

class _Fila extends StatelessWidget {
  final String k;
  final String v;
  const _Fila(this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: Colores.atenuado, fontSize: 13)),
          Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );
}
