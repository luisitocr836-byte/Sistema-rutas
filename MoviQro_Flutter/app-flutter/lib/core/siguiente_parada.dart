import 'dart:math' as math;

import 'geo.dart';
import 'tipos.dart';

class SiguienteParada {
  final Parada parada;

  /// Distancia a lo largo del trazado desde la unidad hasta la parada (m).
  final double distanciaPorRutaM;

  /// Posición de la parada a lo largo del trazado (m desde el inicio).
  final double posicionParadaM;

  /// Posición de la unidad a lo largo del trazado (m desde el inicio).
  final double posicionUnidadM;

  /// Distancia perpendicular de la unidad al trazado (m). Útil para detectar desvíos.
  final double desvioDeRutaM;

  const SiguienteParada({
    required this.parada,
    required this.distanciaPorRutaM,
    required this.posicionParadaM,
    required this.posicionUnidadM,
    required this.desvioDeRutaM,
  });
}

/// Tolerancia (m): una parada que está hasta esta distancia "detrás" de la unidad se sigue
/// considerando por llegar (ruido GPS cerca de la parada).
const double toleranciaSiguienteParadaM = 25;

/// Determina la siguiente parada relevante de una unidad sobre su ruta: proyecta la unidad y cada
/// parada sobre el trazado y elige la primera parada (por orden de secuencia) que aún no se rebasó.
///
/// Devuelve null si faltan datos (ruta sin trazado, sin paradas) o si la unidad ya rebasó la última parada.
SiguienteParada? seleccionarSiguienteParada(
  List<Coordenada> trazado,
  List<Parada> paradas,
  Coordenada posicionUnidad, {
  double toleranciaM = toleranciaSiguienteParadaM,
}) {
  if (trazado.length < 2 || paradas.isEmpty) return null;

  final proyUnidad = proyectarEnRuta(trazado, posicionUnidad);

  final conPosicion = [
    for (final p in paradas) (parada: p, posicionM: proyectarEnRuta(trazado, p).distanciaAlolargoM),
  ]..sort((a, b) => a.parada.ordenSecuencia.compareTo(b.parada.ordenSecuencia));

  for (final c in conPosicion) {
    if (c.posicionM >= proyUnidad.distanciaAlolargoM - toleranciaM) {
      return SiguienteParada(
        parada: c.parada,
        distanciaPorRutaM: math.max(0.0, c.posicionM - proyUnidad.distanciaAlolargoM),
        posicionParadaM: c.posicionM,
        posicionUnidadM: proyUnidad.distanciaAlolargoM,
        desvioDeRutaM: proyUnidad.distanciaALineaM,
      );
    }
  }
  return null;
}
