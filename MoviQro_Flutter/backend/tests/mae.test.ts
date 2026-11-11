import { describe, expect, it } from 'vitest';
import { calcularMAE, errorAbsolutoMin, errorPorcentual, esObservacionValida } from '../core';

describe('error absoluto y porcentual', () => {
  it('ejemplo numérico: 1.20 vs 1.35 → 0.15 min, 11.11 %', () => {
    expect(errorAbsolutoMin(1.2, 1.35)).toBeCloseTo(0.15, 10);
    expect(errorPorcentual(1.2, 1.35)).toBeCloseTo(11.11, 2);
  });
  it('ejemplo numérico: 9.50 vs 10.80 → 1.30 min, 12.04 %', () => {
    expect(errorAbsolutoMin(9.5, 10.8)).toBeCloseTo(1.3, 10);
    expect(errorPorcentual(9.5, 10.8)).toBeCloseTo(12.04, 2);
  });
  it('es simétrico (sobre y subestimación)', () => {
    expect(errorAbsolutoMin(5, 3)).toBe(errorAbsolutoMin(3, 5));
  });
  it('error porcentual con tiempo real 0 lanza error', () => {
    expect(() => errorPorcentual(1, 0)).toThrow();
  });
});

describe('calcularMAE', () => {
  it('promedia los errores absolutos de las observaciones válidas', () => {
    const r = calcularMAE([
      { etaEstimadoMin: 2, tiempoRealMin: 3 }, // 1
      { etaEstimadoMin: 10, tiempoRealMin: 8 }, // 2
      { etaEstimadoMin: 5, tiempoRealMin: 5 }, // 0
    ]);
    expect(r.n).toBe(3);
    expect(r.descartadas).toBe(0);
    expect(r.maeMin).toBeCloseTo(1, 10);
    expect(r.maxErrorMin).toBe(2);
  });
  it('MAE de tres observaciones (errores 0.15, 1.30 y 0.05 → 0.50 min)', () => {
    const r = calcularMAE([
      { etaEstimadoMin: 1.2, tiempoRealMin: 1.35 },
      { etaEstimadoMin: 9.5, tiempoRealMin: 10.8 },
      { etaEstimadoMin: 0.85, tiempoRealMin: 0.9 },
    ]);
    expect(r.maeMin).toBeCloseTo((0.15 + 1.3 + 0.05) / 3, 10);
  });
  it('maneja datos faltantes: descarta null/undefined/NaN/negativos/tiempo real 0', () => {
    const r = calcularMAE([
      { etaEstimadoMin: 2, tiempoRealMin: 4 },
      { etaEstimadoMin: 2, tiempoRealMin: null },
      { etaEstimadoMin: null, tiempoRealMin: 3 },
      { etaEstimadoMin: undefined, tiempoRealMin: undefined },
      { etaEstimadoMin: NaN, tiempoRealMin: 3 },
      { etaEstimadoMin: 3, tiempoRealMin: 0 },
      { etaEstimadoMin: -1, tiempoRealMin: 3 },
    ]);
    expect(r.n).toBe(1);
    expect(r.descartadas).toBe(6);
    expect(r.maeMin).toBe(2);
  });
  it('sin observaciones válidas el MAE es null (no 0)', () => {
    const r = calcularMAE([{ etaEstimadoMin: 1, tiempoRealMin: null }]);
    expect(r.n).toBe(0);
    expect(r.maeMin).toBeNull();
    expect(r.mapePct).toBeNull();
    expect(calcularMAE([]).maeMin).toBeNull();
  });
  it('esObservacionValida', () => {
    expect(esObservacionValida({ etaEstimadoMin: 0, tiempoRealMin: 1 })).toBe(true);
    expect(esObservacionValida({ etaEstimadoMin: 1, tiempoRealMin: 0 })).toBe(false);
  });
});
