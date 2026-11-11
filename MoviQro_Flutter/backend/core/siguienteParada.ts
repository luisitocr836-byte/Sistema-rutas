import { proyectarEnRuta } from './geo';
import type { Coordenada, Parada } from './types';

export interface SiguienteParada {
  parada: Parada;
  /** Distancia a lo largo del trazado desde la unidad hasta la parada (m). */
  distanciaPorRutaM: number;
  /** Posición de la parada a lo largo del trazado (m desde el inicio). */
  posicionParadaM: number;
  /** Posición de la unidad a lo largo del trazado (m desde el inicio). */
  posicionUnidadM: number;
  /** Distancia perpendicular de la unidad al trazado (m). Útil para detectar desvíos. */
  desvioDeRutaM: number;
}

export interface OpcionesSiguienteParada {
  /**
   * Tolerancia (m): una parada que está hasta esta distancia "detrás" de la unidad se
   * sigue considerando por llegar (ruido GPS cerca de la parada).
   */
  toleranciaM: number;
}

export const OPCIONES_SIGUIENTE_PARADA: OpcionesSiguienteParada = { toleranciaM: 25 };

/**
 * Determina la siguiente parada relevante de una unidad sobre su ruta:
 * proyecta la unidad y cada parada sobre el trazado y elige la primera parada
 * (por posición a lo largo de la ruta) que aún no se ha rebasado.
 *
 * Devuelve null si faltan datos (ruta sin trazado, sin paradas) o si la unidad
 * ya rebasó la última parada.
 */
export function seleccionarSiguienteParada(
  trazado: Coordenada[],
  paradas: Parada[],
  posicionUnidad: Coordenada,
  opciones: OpcionesSiguienteParada = OPCIONES_SIGUIENTE_PARADA,
): SiguienteParada | null {
  if (trazado.length < 2 || paradas.length === 0) return null;

  const proyUnidad = proyectarEnRuta(trazado, posicionUnidad);

  const conPosicion = paradas
    .map((p) => ({ parada: p, posicionM: proyectarEnRuta(trazado, p).distanciaAlolargoM }))
    .sort((a, b) => a.parada.ordenSecuencia - b.parada.ordenSecuencia);

  const candidata = conPosicion.find((p) => p.posicionM >= proyUnidad.distanciaAlolargoM - opciones.toleranciaM);
  if (!candidata) return null;

  return {
    parada: candidata.parada,
    distanciaPorRutaM: Math.max(0, candidata.posicionM - proyUnidad.distanciaAlolargoM),
    posicionParadaM: candidata.posicionM,
    posicionUnidadM: proyUnidad.distanciaAlolargoM,
    desvioDeRutaM: proyUnidad.distanciaALineaM,
  };
}
