import { validarCoordenadas } from './geo';
import type { LecturaGps, OrigenDato } from './types';

/**
 * Buffer local de telemetría (Avance 2, sección 9.B): ante pérdida de conectividad se conservan
 * hasta 20 posiciones y se transmiten en ráfaga al restablecerse. Si se llena, se descarta la
 * más antigua (la posición más reciente es la más valiosa para un seguimiento en vivo).
 */
export const CAPACIDAD_BUFFER_POR_DEFECTO = 20;

export class BufferTelemetria {
  private cola: LecturaGps[] = [];
  private vaciando = false;
  /** Número de lecturas descartadas por desbordamiento desde que se creó el buffer. */
  descartadas = 0;

  constructor(readonly capacidad: number = CAPACIDAD_BUFFER_POR_DEFECTO) {
    if (!Number.isInteger(capacidad) || capacidad < 1) throw new Error('La capacidad debe ser un entero >= 1.');
  }

  get tamano(): number {
    return this.cola.length;
  }

  agregar(lectura: LecturaGps): void {
    this.cola.push(lectura);
    while (this.cola.length > this.capacidad) {
      this.cola.shift();
      this.descartadas++;
    }
  }

  /**
   * Intenta enviar todo lo acumulado en una sola ráfaga. Si `enviar` lanza, las lecturas se
   * conservan (antes de las que lleguen mientras tanto) y se devuelve el error.
   * Si ya hay un envío en curso, no hace nada.
   */
  async vaciar(enviar: (lote: LecturaGps[]) => Promise<void>): Promise<{ enviadas: number; error?: string }> {
    if (this.vaciando || this.cola.length === 0) return { enviadas: 0 };
    this.vaciando = true;
    const lote = this.cola;
    this.cola = [];
    try {
      await enviar(lote);
      return { enviadas: lote.length };
    } catch (e) {
      this.cola = [...lote, ...this.cola];
      while (this.cola.length > this.capacidad) {
        this.cola.shift();
        this.descartadas++;
      }
      return { enviadas: 0, error: e instanceof Error ? e.message : String(e) };
    } finally {
      this.vaciando = false;
    }
  }

  /** Copia de solo lectura del contenido actual (para persistirlo, p. ej. en segundo plano). */
  instantanea(): LecturaGps[] {
    return [...this.cola];
  }
}

export interface FilaCoordenadasLog {
  id_unidad: number;
  latitud: number;
  longitud: number;
  velocidad_kmh: number | null;
  precision_gps_m: number | null;
  fecha_hora: string;
  origen_dato: OrigenDato;
}

/** Convierte una lectura en la fila que se inserta en coordenadas_log. Lanza si la lectura es inválida. */
export function aFilaCoordenadasLog(idUnidad: number, l: LecturaGps): FilaCoordenadasLog {
  if (!Number.isInteger(idUnidad) || idUnidad <= 0) throw new Error('Identificador de unidad inválido.');
  const v = validarCoordenadas(l.latitud, l.longitud);
  if (!v.valido) throw new Error(v.motivo);
  if (!Number.isFinite(l.timestampMs)) throw new Error('Marca de tiempo inválida.');
  if (l.velocidadKmh !== null && (!Number.isFinite(l.velocidadKmh) || l.velocidadKmh < 0 || l.velocidadKmh > 200)) {
    throw new Error('Velocidad fuera de rango (0–200 km/h).');
  }
  return {
    id_unidad: idUnidad,
    latitud: l.latitud,
    longitud: l.longitud,
    velocidad_kmh: l.velocidadKmh === null ? null : Math.round(l.velocidadKmh * 100) / 100,
    precision_gps_m: l.precisionM !== null && Number.isFinite(l.precisionM) && l.precisionM >= 0 ? l.precisionM : null,
    fecha_hora: new Date(l.timestampMs).toISOString(),
    origen_dato: l.origen,
  };
}
