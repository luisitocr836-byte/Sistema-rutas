import type { CondicionTrafico, LecturaGps } from './types';

export interface ConfigVelocidad {
  /** Por debajo de este valor (km/h) la unidad se considera detenida. */
  umbralDetenidaKmh: number;
  /** Precisión GPS máxima aceptable (m) para confiar en la velocidad. */
  precisionMaximaM: number;
  /** Edad máxima (ms) de un registro para considerarlo vigente. */
  edadMaximaMs: number;
  /** Velocidad máxima verosímil (km/h) para un autobús urbano; mayores se descartan. */
  velocidadMaximaKmh: number;
  /** Factor del suavizado exponencial (0..1). Mayor = reacciona más rápido. */
  alfaSuavizado: number;
}

export const CONFIG_VELOCIDAD_POR_DEFECTO: ConfigVelocidad = {
  umbralDetenidaKmh: 2,
  precisionMaximaM: 50,
  edadMaximaMs: 60_000,
  velocidadMaximaKmh: 110,
  alfaSuavizado: 0.4,
};

/** ¿El registro es demasiado antiguo para usarse en un ETA? */
export function esRegistroAntiguo(
  lectura: Pick<LecturaGps, 'timestampMs'>,
  ahoraMs: number,
  config: ConfigVelocidad = CONFIG_VELOCIDAD_POR_DEFECTO,
): boolean {
  return ahoraMs - lectura.timestampMs > config.edadMaximaMs;
}

/** Una velocidad es "confiable" si existe, es verosímil y la precisión GPS es buena. */
export function velocidadEsConfiable(
  lectura: Pick<LecturaGps, 'velocidadKmh' | 'precisionM'>,
  config: ConfigVelocidad = CONFIG_VELOCIDAD_POR_DEFECTO,
): boolean {
  const v = lectura.velocidadKmh;
  if (v === null || !Number.isFinite(v) || v < 0 || v > config.velocidadMaximaKmh) return false;
  if (lectura.precisionM !== null && lectura.precisionM > config.precisionMaximaM) return false;
  return true;
}

export function estaDetenida(velocidadKmh: number | null, config: ConfigVelocidad = CONFIG_VELOCIDAD_POR_DEFECTO): boolean {
  return velocidadKmh !== null && velocidadKmh < config.umbralDetenidaKmh;
}

/**
 * Suavizado exponencial (EMA) sobre las lecturas cuya velocidad sea confiable.
 * `lecturas` debe estar en orden cronológico ascendente.
 * Devuelve null si ninguna lectura es utilizable.
 */
export function suavizarVelocidadKmh(
  lecturas: Pick<LecturaGps, 'velocidadKmh' | 'precisionM'>[],
  config: ConfigVelocidad = CONFIG_VELOCIDAD_POR_DEFECTO,
): number | null {
  let ema: number | null = null;
  for (const l of lecturas) {
    if (!velocidadEsConfiable(l, config)) continue;
    const v = l.velocidadKmh as number;
    ema = ema === null ? v : config.alfaSuavizado * v + (1 - config.alfaSuavizado) * ema;
  }
  return ema;
}

/**
 * Clasificación orientativa de la condición de tráfico a partir de la relación
 * entre la velocidad suavizada y una velocidad de referencia de la vía.
 * Es una heurística de presentación, NO una medición de tráfico.
 */
export function clasificarCondicionTrafico(
  velocidadSuavizadaKmh: number | null,
  velocidadReferenciaKmh: number,
): CondicionTrafico {
  if (velocidadSuavizadaKmh === null || velocidadReferenciaKmh <= 0) return 'desconocido';
  const razon = velocidadSuavizadaKmh / velocidadReferenciaKmh;
  if (razon >= 0.75) return 'fluido';
  if (razon >= 0.4) return 'moderado';
  return 'denso';
}
