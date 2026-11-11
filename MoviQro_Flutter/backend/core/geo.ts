import type { Coordenada } from './types';

const RADIO_TIERRA_M = 6371008.8;

/** Límites aproximados para el área de operación (San Juan del Río, Qro.) con margen amplio. */
export const LIMITES_REGION_OPERACION = {
  latMin: 20.2,
  latMax: 20.6,
  lonMin: -100.2,
  lonMax: -99.8,
} as const;

export interface ResultadoValidacion {
  valido: boolean;
  motivo?: string;
}

/**
 * Valida un par (latitud, longitud) en WGS84.
 * Rechaza NaN/Infinity, valores fuera de rango y el punto (0,0), que es el
 * valor típico de un GPS sin fijar posición.
 */
export function validarCoordenadas(latitud: unknown, longitud: unknown): ResultadoValidacion {
  if (typeof latitud !== 'number' || typeof longitud !== 'number') {
    return { valido: false, motivo: 'Latitud y longitud deben ser números.' };
  }
  if (!Number.isFinite(latitud) || !Number.isFinite(longitud)) {
    return { valido: false, motivo: 'Latitud y longitud deben ser finitas.' };
  }
  if (latitud < -90 || latitud > 90) {
    return { valido: false, motivo: 'La latitud debe estar entre -90 y 90.' };
  }
  if (longitud < -180 || longitud > 180) {
    return { valido: false, motivo: 'La longitud debe estar entre -180 y 180.' };
  }
  if (latitud === 0 && longitud === 0) {
    return { valido: false, motivo: 'Coordenada (0,0): probable GPS sin posición.' };
  }
  return { valido: true };
}

/** Comprueba si la coordenada cae dentro de la región de operación configurada. */
export function estaEnRegionOperacion(c: Coordenada): boolean {
  const l = LIMITES_REGION_OPERACION;
  return c.latitud >= l.latMin && c.latitud <= l.latMax && c.longitud >= l.lonMin && c.longitud <= l.lonMax;
}

/** Km/h → m/s */
export function kmhAMs(kmh: number): number {
  return kmh / 3.6;
}

/** m/s → km/h */
export function msAKmh(ms: number): number {
  return ms * 3.6;
}

/**
 * Convierte la velocidad que entrega expo-location (m/s, puede ser null o negativa
 * cuando no es válida) a km/h. Devuelve null si el dato no es utilizable.
 */
export function velocidadDispositivoAKmh(velocidadMs: number | null | undefined): number | null {
  if (velocidadMs === null || velocidadMs === undefined) return null;
  if (!Number.isFinite(velocidadMs) || velocidadMs < 0) return null;
  return msAKmh(velocidadMs);
}

function aRad(grados: number): number {
  return (grados * Math.PI) / 180;
}

/** Distancia en línea recta (haversine) en metros. Solo referencia; NO es distancia vial. */
export function distanciaHaversineM(a: Coordenada, b: Coordenada): number {
  const dLat = aRad(b.latitud - a.latitud);
  const dLon = aRad(b.longitud - a.longitud);
  const lat1 = aRad(a.latitud);
  const lat2 = aRad(b.latitud);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * RADIO_TIERRA_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Longitud total de una polilínea en metros. */
export function longitudPolilineaM(linea: Coordenada[]): number {
  let total = 0;
  for (let i = 1; i < linea.length; i++) total += distanciaHaversineM(linea[i - 1], linea[i]);
  return total;
}

export interface ProyeccionEnRuta {
  /** Distancia acumulada desde el inicio de la ruta hasta el punto proyectado (m). */
  distanciaAlolargoM: number;
  /** Distancia perpendicular del punto original a la ruta (m). */
  distanciaALineaM: number;
  /** Índice del segmento sobre el que se proyectó. */
  indiceSegmento: number;
  puntoProyectado: Coordenada;
}

/**
 * Proyecta un punto sobre una polilínea usando una aproximación plana local
 * (equirectangular), adecuada para distancias urbanas de unos pocos km.
 * Equivale conceptualmente a ST_LineLocatePoint(linea, punto) * ST_Length(linea).
 */
export function proyectarEnRuta(linea: Coordenada[], punto: Coordenada): ProyeccionEnRuta {
  if (linea.length < 2) {
    throw new Error('La ruta necesita al menos 2 vértices.');
  }
  const lat0 = aRad(punto.latitud);
  const kx = Math.cos(lat0) * ((Math.PI / 180) * RADIO_TIERRA_M);
  const ky = (Math.PI / 180) * RADIO_TIERRA_M;

  let mejor: ProyeccionEnRuta | null = null;
  let acumulado = 0;

  for (let i = 1; i < linea.length; i++) {
    const a = linea[i - 1];
    const b = linea[i];
    const ax = (a.longitud - punto.longitud) * kx;
    const ay = (a.latitud - punto.latitud) * ky;
    const bx = (b.longitud - punto.longitud) * kx;
    const by = (b.latitud - punto.latitud) * ky;
    const dx = bx - ax;
    const dy = by - ay;
    const largo2 = dx * dx + dy * dy;
    let t = largo2 === 0 ? 0 : -(ax * dx + ay * dy) / largo2;
    t = Math.max(0, Math.min(1, t));
    const px = ax + t * dx;
    const py = ay + t * dy;
    const dist = Math.hypot(px, py);
    const largoSegmento = distanciaHaversineM(a, b);

    if (mejor === null || dist < mejor.distanciaALineaM) {
      mejor = {
        distanciaAlolargoM: acumulado + t * largoSegmento,
        distanciaALineaM: dist,
        indiceSegmento: i - 1,
        puntoProyectado: {
          latitud: a.latitud + t * (b.latitud - a.latitud),
          longitud: a.longitud + t * (b.longitud - a.longitud),
        },
      };
    }
    acumulado += largoSegmento;
  }
  return mejor as ProyeccionEnRuta;
}

/** Punto situado a `distanciaM` metros del inicio, medido a lo largo de la polilínea. */
export function puntoAlolargoDeRuta(linea: Coordenada[], distanciaM: number): Coordenada {
  if (linea.length === 0) throw new Error('Ruta vacía.');
  if (linea.length === 1 || distanciaM <= 0) return linea[0];
  let restante = distanciaM;
  for (let i = 1; i < linea.length; i++) {
    const tramo = distanciaHaversineM(linea[i - 1], linea[i]);
    if (restante <= tramo && tramo > 0) {
      const t = restante / tramo;
      return {
        latitud: linea[i - 1].latitud + t * (linea[i].latitud - linea[i - 1].latitud),
        longitud: linea[i - 1].longitud + t * (linea[i].longitud - linea[i - 1].longitud),
      };
    }
    restante -= tramo;
  }
  return linea[linea.length - 1];
}
