import { describe, expect, it } from 'vitest';
import {
  distanciaHaversineM,
  estaEnRegionOperacion,
  kmhAMs,
  msAKmh,
  validarCoordenadas,
  velocidadDispositivoAKmh,
} from '../core';

describe('validarCoordenadas', () => {
  it('acepta una coordenada válida de San Juan del Río', () => {
    expect(validarCoordenadas(20.3889, -99.9961).valido).toBe(true);
  });
  it.each([
    [91, -99],
    [-91, -99],
    [20, 181],
    [20, -181],
  ])('rechaza fuera de rango (%s, %s)', (lat, lon) => {
    expect(validarCoordenadas(lat, lon).valido).toBe(false);
  });
  it('rechaza NaN, Infinity, null, undefined y cadenas', () => {
    expect(validarCoordenadas(NaN, -99).valido).toBe(false);
    expect(validarCoordenadas(20, Infinity).valido).toBe(false);
    expect(validarCoordenadas(null, -99).valido).toBe(false);
    expect(validarCoordenadas(undefined, undefined).valido).toBe(false);
    expect(validarCoordenadas('20.3', '-99.9').valido).toBe(false);
  });
  it('rechaza (0,0) como GPS sin posición', () => {
    const r = validarCoordenadas(0, 0);
    expect(r.valido).toBe(false);
    expect(r.motivo).toMatch(/GPS/);
  });
  it('detecta latitud/longitud invertidas en México: lat=-99.99 queda fuera de rango', () => {
    expect(validarCoordenadas(-99.99, 20.38).valido).toBe(false);
  });
});

describe('región de operación', () => {
  it('reconoce San Juan del Río y rechaza Ciudad de México', () => {
    expect(estaEnRegionOperacion({ latitud: 20.3889, longitud: -99.9961 })).toBe(true);
    expect(estaEnRegionOperacion({ latitud: 19.4326, longitud: -99.1332 })).toBe(false);
  });
});

describe('conversión de velocidades', () => {
  it('km/h ↔ m/s', () => {
    expect(kmhAMs(36)).toBeCloseTo(10, 10);
    expect(msAKmh(10)).toBeCloseTo(36, 10);
    expect(msAKmh(kmhAMs(47.3))).toBeCloseTo(47.3, 10);
  });
  it('velocidad del dispositivo (m/s) → km/h; null y negativos no son utilizables', () => {
    expect(velocidadDispositivoAKmh(5)).toBeCloseTo(18, 10);
    expect(velocidadDispositivoAKmh(0)).toBe(0);
    expect(velocidadDispositivoAKmh(null)).toBeNull();
    expect(velocidadDispositivoAKmh(undefined)).toBeNull();
    expect(velocidadDispositivoAKmh(-1)).toBeNull(); // expo-location usa -1 cuando no hay dato
    expect(velocidadDispositivoAKmh(NaN)).toBeNull();
  });
});

describe('distanciaHaversineM', () => {
  it('0 m entre el mismo punto', () => {
    const p = { latitud: 20.3889, longitud: -99.9961 };
    expect(distanciaHaversineM(p, p)).toBe(0);
  });
  it('un grado de latitud ≈ 111.2 km', () => {
    const d = distanciaHaversineM({ latitud: 20, longitud: -100 }, { latitud: 21, longitud: -100 });
    expect(d).toBeGreaterThan(111_000);
    expect(d).toBeLessThan(111_400);
  });
});
