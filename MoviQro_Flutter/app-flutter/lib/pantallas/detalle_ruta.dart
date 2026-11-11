import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/tema.dart';
import '../core/core.dart';
import '../estado/datos_modelo.dart';
import '../widgets/comunes.dart';
import '../widgets/mapa_ruta.dart';
import '../widgets/panel_seguimiento.dart';
import '../widgets/tarjeta_ruta.dart';

class PantallaDetalleRuta extends StatelessWidget {
  final String numeroRuta;
  const PantallaDetalleRuta({super.key, required this.numeroRuta});

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosModelo>();
    final rp = datos.rutaPorNumero(numeroRuta);

    if (rp == null) {
      return PantallaBase(
        titulo: 'Ruta $numeroRuta',
        conVolver: true,
        hijos: [
          datos.cargando
              ? const EstadoCarga('Cargando ruta…')
              : EstadoVacio('No se encontró la ruta $numeroRuta.', accion: TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Volver'))),
        ],
      );
    }

    final r = rp.ruta;
    final color = colorDeHex(r.colorHex);
    final unidad = datos.unidadDeRuta(r.idRuta);
    final est = unidad == null ? null : datos.estimaciones[unidad.idUnidad];

    String? horario;
    if (r.horarioInicio != null && r.horarioFin != null) horario = '${r.horarioInicio} – ${r.horarioFin}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Ruta ${r.numeroRuta}'),
        actions: [BotonFavorito(numeroRuta: r.numeroRuta)],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: datos.recargar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                  child: Text(r.numeroRuta, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(r.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 10),
              Text('${r.origen} → ${r.destino}', style: const TextStyle(color: Colores.atenuado)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (r.fuenteDatos == FuenteDatos.demostracion) const InsigniaDato(TipoDato.demostracion),
                if (horario != null) Chip(label: Text(horario), visualDensity: VisualDensity.compact),
                if (r.frecuenciaPromedioMin != null) Chip(label: Text('Cada ~${r.frecuenciaPromedioMin} min'), visualDensity: VisualDensity.compact),
                if (r.distanciaKm != null) Chip(label: Text('${r.distanciaKm!.toStringAsFixed(1)} km'), visualDensity: VisualDensity.compact),
              ]),
              if (r.fuenteDatos == FuenteDatos.demostracion) ...[
                const SizedBox(height: 10),
                const CajaInfo(texto: 'DEMOSTRACIÓN: el trazado y las paradas son ilustrativos, no el recorrido oficial. Verifica con información oficial antes de viajar.'),
              ],
              const SizedBox(height: 16),
              MapaRuta(rutas: [rp], unidades: datos.unidades, idParadaObjetivo: est?.idParadaObjetivo),
              const SizedBox(height: 16),
              PanelSeguimiento(rutaConParadas: rp),
              const SizedBox(height: 18),
              const Text('Paradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (rp.paradas.isEmpty)
                const EstadoVacio('Esta ruta aún no tiene paradas registradas.')
              else
                ListaParadas(paradas: rp.paradas, idParadaObjetivo: est?.idParadaObjetivo, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
