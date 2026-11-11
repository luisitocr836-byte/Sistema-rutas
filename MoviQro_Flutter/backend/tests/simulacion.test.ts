import { describe, expect, it } from 'vitest';
import { SimuladorUnidad, distanciaHaversineM, kmhAMs } from '../core';
import { AHORA, LARGO_RUTA_M, RUTA } from './helpers';

describe('SimuladorUnidad (modo Demostración)', () => {
  it('todas las lecturas se marcan como simuladas', () => {
    const s = new SimuladorUnidad({ trazado: RUTA.trazado, velocidadKmh: 30, intervaloS: 4, bucle: false }, AHORA);
    expect(s.actual().origen).toBe('simulado');
    expect(s.avanzar().origen).toBe('simulado');
  });
  it('avanza velocidad × intervalo metros por paso (determinista)', () => {
    const s = new SimuladorUnidad({ trazado: RUTA.trazado, velocidadKmh: 36, intervaloS: 5, bucle: false }, AHORA);
    const a = s.actual();
    const b = s.avanzar();
    expect(b.timestampMs - a.timestampMs).toBe(5000);
    expect(distanciaHaversineM(a, b)).toBeGreaterThan(40); // 10 m/s × 5 s = 50 m a lo largo de la ruta
    expect(distanciaHaversineM(a, b)).toBeLessThanOrEqual(50.5);
  });
  it('sin bucle termina en el último punto con velocidad 0', () => {
    const s = new SimuladorUnidad({ trazado: RUTA.trazado, velocidadKmh: 200, intervaloS: 60, bucle: false }, AHORA);
    let guardia = 0;
    while (!s.terminado && guardia++ < 1000) s.avanzar();
    expect(s.terminado).toBe(true);
    expect(s.actual().velocidadKmh).toBe(0);
    expect(distanciaHaversineM(s.actual(), RUTA.trazado[RUTA.trazado.length - 1])).toBeLessThan(1);
  });
  it('con bucle nunca termina', () => {
    const s = new SimuladorUnidad({ trazado: RUTA.trazado, velocidadKmh: kmhAMs(1) * 3.6 * 500, intervaloS: 10, bucle: true }, AHORA);
    for (let i = 0; i < 50; i++) s.avanzar();
    expect(s.terminado).toBe(false);
    expect(s.largoTrazadoM).toBeCloseTo(LARGO_RUTA_M, 3);
  });
  it('valida parámetros', () => {
    expect(() => new SimuladorUnidad({ trazado: [], velocidadKmh: 10, intervaloS: 1, bucle: false }, 0)).toThrow();
    expect(() => new SimuladorUnidad({ trazado: RUTA.trazado, velocidadKmh: 0, intervaloS: 1, bucle: false }, 0)).toThrow();
    expect(() => new SimuladorUnidad({ trazado: RUTA.trazado, velocidadKmh: 10, intervaloS: 0, bucle: false }, 0)).toThrow();
  });
});
