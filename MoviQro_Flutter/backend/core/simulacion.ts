import { longitudPolilineaM, puntoAlolargoDeRuta, kmhAMs } from './geo';
import type { Coordenada, LecturaGps } from './types';

/**
 * Generador de posiciones simuladas a lo largo de un trazado (modo "Demostración").
 * Toda lectura producida lleva origen = 'simulado'. Es determinista: la misma
 * configuración produce la misma secuencia (no usa aleatoriedad).
 */
export interface ConfigSimulacion {
  trazado: Coordenada[];
  /** Velocidad constante del autobús simulado (km/h). */
  velocidadKmh: number;
  /** Segundos de tiempo simulado entre lecturas. */
  intervaloS: number;
  /** Si true, al llegar al final vuelve a empezar. */
  bucle: boolean;
  /** Distancia inicial (m) desde el inicio del trazado. */
  inicioM?: number;
}

export class SimuladorUnidad {
  private distanciaM: number;
  private readonly largoM: number;
  private tiempoMs: number;

  constructor(
    private readonly config: ConfigSimulacion,
    tiempoInicialMs: number,
  ) {
    if (config.trazado.length < 2) throw new Error('El trazado necesita al menos 2 puntos.');
    if (!(config.velocidadKmh > 0)) throw new Error('La velocidad simulada debe ser mayor que 0.');
    if (!(config.intervaloS > 0)) throw new Error('El intervalo debe ser mayor que 0.');
    this.largoM = longitudPolilineaM(config.trazado);
    this.distanciaM = Math.min(config.inicioM ?? 0, this.largoM);
    this.tiempoMs = tiempoInicialMs;
  }

  get largoTrazadoM(): number {
    return this.largoM;
  }

  get terminado(): boolean {
    return !this.config.bucle && this.distanciaM >= this.largoM;
  }

  /** Lectura en el instante actual (sin avanzar). */
  actual(): LecturaGps {
    const p = puntoAlolargoDeRuta(this.config.trazado, this.distanciaM);
    return {
      latitud: p.latitud,
      longitud: p.longitud,
      velocidadKmh: this.terminado ? 0 : this.config.velocidadKmh,
      precisionM: 5,
      timestampMs: this.tiempoMs,
      origen: 'simulado',
    };
  }

  /** Avanza `intervaloS` segundos de tiempo simulado y devuelve la nueva lectura. */
  avanzar(): LecturaGps {
    this.tiempoMs += this.config.intervaloS * 1000;
    this.distanciaM += kmhAMs(this.config.velocidadKmh) * this.config.intervaloS;
    if (this.distanciaM >= this.largoM) {
      if (this.config.bucle) this.distanciaM = this.distanciaM % this.largoM;
      else this.distanciaM = this.largoM;
    }
    return this.actual();
  }
}
