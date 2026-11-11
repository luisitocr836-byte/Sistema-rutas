/**
 * Métricas de error para la validación del ETA (Etapa 5 de la metodología).
 *
 *   error absoluto  = | ETA estimado − tiempo real observado |   (minutos)
 *   error %         = error absoluto / tiempo real × 100
 *   MAE             = promedio de los errores absolutos de las observaciones válidas
 *
 * Una observación es válida si ambos tiempos son números finitos y el tiempo real es > 0.
 * Las estimaciones sin tiempo real observado NO entran al MAE.
 */

export interface ObservacionEta {
  etaEstimadoMin: number | null | undefined;
  tiempoRealMin: number | null | undefined;
}

export function esObservacionValida(o: ObservacionEta): o is { etaEstimadoMin: number; tiempoRealMin: number } {
  return (
    typeof o.etaEstimadoMin === 'number' &&
    typeof o.tiempoRealMin === 'number' &&
    Number.isFinite(o.etaEstimadoMin) &&
    Number.isFinite(o.tiempoRealMin) &&
    o.etaEstimadoMin >= 0 &&
    o.tiempoRealMin > 0
  );
}

export function errorAbsolutoMin(etaEstimadoMin: number, tiempoRealMin: number): number {
  return Math.abs(etaEstimadoMin - tiempoRealMin);
}

export function errorPorcentual(etaEstimadoMin: number, tiempoRealMin: number): number {
  if (tiempoRealMin <= 0) throw new Error('El tiempo real debe ser mayor que cero.');
  return (errorAbsolutoMin(etaEstimadoMin, tiempoRealMin) / tiempoRealMin) * 100;
}

export interface ResumenError {
  /** Número de observaciones válidas utilizadas. */
  n: number;
  /** Número de observaciones descartadas por datos faltantes o inválidos. */
  descartadas: number;
  /** Error Absoluto Medio en minutos; null si n = 0. */
  maeMin: number | null;
  /** Error porcentual medio (MAPE); null si n = 0. */
  mapePct: number | null;
  /** Error absoluto máximo; null si n = 0. */
  maxErrorMin: number | null;
}

export function calcularMAE(observaciones: ObservacionEta[]): ResumenError {
  const validas = observaciones.filter(esObservacionValida);
  const descartadas = observaciones.length - validas.length;
  if (validas.length === 0) {
    return { n: 0, descartadas, maeMin: null, mapePct: null, maxErrorMin: null };
  }
  const errores = validas.map((o) => errorAbsolutoMin(o.etaEstimadoMin, o.tiempoRealMin));
  const porcentuales = validas.map((o) => errorPorcentual(o.etaEstimadoMin, o.tiempoRealMin));
  const suma = (xs: number[]) => xs.reduce((a, b) => a + b, 0);
  return {
    n: validas.length,
    descartadas,
    maeMin: suma(errores) / errores.length,
    mapePct: suma(porcentuales) / porcentuales.length,
    maxErrorMin: Math.max(...errores),
  };
}
