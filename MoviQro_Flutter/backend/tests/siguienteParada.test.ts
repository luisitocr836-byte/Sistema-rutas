import { describe, expect, it } from 'vitest';
import { proyectarEnRuta, seleccionarSiguienteParada } from '../core';
import { PARADAS, RUTA, enRuta, LARGO_RUTA_M } from './helpers';

const posParada = (orden: number) => proyectarEnRuta(RUTA.trazado, PARADAS.find((p) => p.ordenSecuencia === orden)!).distanciaAlolargoM;

describe('proyección sobre la ruta', () => {
  it('un punto del trazado se proyecta con desvío ≈ 0 y a la distancia esperada', () => {
    const p = proyectarEnRuta(RUTA.trazado, enRuta(1234));
    expect(p.distanciaALineaM).toBeLessThan(0.5);
    expect(p.distanciaAlolargoM).toBeCloseTo(1234, 0);
  });
  it('requiere al menos 2 vértices', () => {
    expect(() => proyectarEnRuta([{ latitud: 20, longitud: -99 }], { latitud: 20, longitud: -99 })).toThrow();
  });
});

describe('seleccionarSiguienteParada', () => {
  it('al inicio de la ruta la siguiente es la parada 1 (a ~0 m)', () => {
    const r = seleccionarSiguienteParada(RUTA.trazado, PARADAS, enRuta(0))!;
    expect(r.parada.ordenSecuencia).toBe(1);
    expect(r.distanciaPorRutaM).toBeLessThan(1);
  });
  it('entre la parada 2 y la 3 la siguiente es la 3, con la distancia por ruta correcta', () => {
    const medio = (posParada(2) + posParada(3)) / 2;
    const r = seleccionarSiguienteParada(RUTA.trazado, PARADAS, enRuta(medio))!;
    expect(r.parada.ordenSecuencia).toBe(3);
    expect(r.distanciaPorRutaM).toBeCloseTo(posParada(3) - medio, 0);
  });
  it('justo después de pasar una parada (> tolerancia) avanza a la siguiente', () => {
    const r = seleccionarSiguienteParada(RUTA.trazado, PARADAS, enRuta(posParada(2) + 60))!;
    expect(r.parada.ordenSecuencia).toBe(3);
  });
  it('dentro de la tolerancia (ruido GPS) la parada recién alcanzada sigue siendo la objetivo', () => {
    const r = seleccionarSiguienteParada(RUTA.trazado, PARADAS, enRuta(posParada(2) + 10))!;
    expect(r.parada.ordenSecuencia).toBe(2);
    expect(r.distanciaPorRutaM).toBe(0);
  });
  it('independiente del orden del arreglo de paradas', () => {
    const barajadas = [...PARADAS].reverse();
    const r = seleccionarSiguienteParada(RUTA.trazado, barajadas, enRuta(posParada(3) - 100))!;
    expect(r.parada.ordenSecuencia).toBe(3);
  });
  it('en la última parada (final del trazado) sigue siendo la objetivo, a 0 m', () => {
    const r = seleccionarSiguienteParada(RUTA.trazado, PARADAS, enRuta(LARGO_RUTA_M))!;
    expect(r.parada.ordenSecuencia).toBe(5);
    expect(r.distanciaPorRutaM).toBe(0);
  });
  it('si la unidad rebasó la última parada de la lista devuelve null', () => {
    const sinUltima = PARADAS.filter((p) => p.ordenSecuencia <= 4);
    expect(seleccionarSiguienteParada(RUTA.trazado, sinUltima, enRuta(LARGO_RUTA_M))).toBeNull();
  });
  it('datos faltantes: sin paradas o sin trazado devuelve null', () => {
    expect(seleccionarSiguienteParada(RUTA.trazado, [], enRuta(10))).toBeNull();
    expect(seleccionarSiguienteParada([], PARADAS, enRuta(10))).toBeNull();
  });
  it('reporta el desvío cuando la unidad está fuera del trazado', () => {
    const p = enRuta(500);
    const r = seleccionarSiguienteParada(RUTA.trazado, PARADAS, { latitud: p.latitud + 0.001, longitud: p.longitud })!;
    expect(r.desvioDeRutaM).toBeGreaterThan(50);
  });
});
