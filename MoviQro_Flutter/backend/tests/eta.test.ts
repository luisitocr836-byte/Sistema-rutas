import { describe, expect, it } from 'vitest';
import {
  CONFIG_ETA_POR_DEFECTO,
  calcularEta,
  clasificarCondicionTrafico,
  estaDetenida,
  proyectarEnRuta,
  suavizarVelocidadKmh,
  velocidadEsConfiable,
} from '../core';
import { AHORA, LARGO_RUTA_M, PARADAS, RUTA, lectura, proveedorFijo, proveedorQueFalla } from './helpers';

const base = { trazado: RUTA.trazado, paradas: PARADAS, ahoraMs: AHORA };
const posParada = (o: number) => proyectarEnRuta(RUTA.trazado, PARADAS.find((p) => p.ordenSecuencia === o)!).distanciaAlolargoM;

describe('calcularEta · datos faltantes y registros inválidos', () => {
  it('sin lecturas → sin_datos_gps, sin ETA', async () => {
    const r = await calcularEta({ ...base, lecturas: [], proveedor: proveedorFijo() });
    expect(r.estado).toBe('sin_datos_gps');
    expect(r.etaMin).toBeUndefined();
  });
  it('coordenada (0,0) → coordenada_invalida', async () => {
    const r = await calcularEta({ ...base, lecturas: [lectura(100, { latitud: 0, longitud: 0 })], proveedor: proveedorFijo() });
    expect(r.estado).toBe('coordenada_invalida');
  });
  it('registro de hace 120 s con vigencia máxima de 60 s → registro_antiguo (no inventa ETA)', async () => {
    const prov = proveedorFijo();
    const r = await calcularEta({ ...base, lecturas: [lectura(100, { timestampMs: AHORA - 120_000 })], proveedor: prov });
    expect(r.estado).toBe('registro_antiguo');
    expect(prov.llamadas).toBe(0);
  });
  it('ruta sin trazado → sin_ruta', async () => {
    const r = await calcularEta({ ...base, trazado: [], lecturas: [lectura(100)], proveedor: proveedorFijo() });
    expect(r.estado).toBe('sin_ruta');
  });
  it('unidad más allá de la última parada → sin_parada_pendiente', async () => {
    const sinUltima = PARADAS.filter((p) => p.ordenSecuencia <= 4);
    const r = await calcularEta({ ...base, paradas: sinUltima, lecturas: [lectura(LARGO_RUTA_M)], proveedor: proveedorFijo() });
    expect(r.estado).toBe('sin_parada_pendiente');
  });
});

describe('calcularEta · con proveedor vial', () => {
  it('combina duración vial (2 min) y velocidad del vehículo (20 km/h, 1 km → 3 min) con peso 0.6 → 2.4 min', async () => {
    const prov = proveedorFijo({ distanciaM: 1000, duracionS: 120 });
    const r = await calcularEta({ ...base, lecturas: [lectura(posParada(2) + 100)], proveedor: prov });
    expect(r.estado).toBe('ok');
    expect(r.fuenteCalculo).toBe('osrm');
    expect(r.distanciaRestanteM).toBe(1000); // usa la distancia VIAL del proveedor, no la euclidiana
    expect(r.etaMin).toBeCloseTo(0.6 * 2 + 0.4 * 3, 6);
    expect(r.advertencias).toHaveLength(0);
    expect(prov.llamadas).toBe(1);
  });
  it('unidad detenida: usa solo la duración vial y avisa', async () => {
    const r = await calcularEta({
      ...base,
      lecturas: [lectura(posParada(2) + 100, { velocidadKmh: 0 })],
      proveedor: proveedorFijo({ duracionS: 180 }),
    });
    expect(r.estado).toBe('ok');
    expect(r.unidadDetenida).toBe(true);
    expect(r.etaMin).toBeCloseTo(3, 6);
    expect(r.advertencias.join(' ')).toMatch(/detenida/);
    expect(Number.isFinite(r.etaMin)).toBe(true); // no se divide entre velocidad ≈ 0
  });
  it('precisión GPS mala (100 m): ignora la velocidad y usa solo la duración vial', async () => {
    const r = await calcularEta({
      ...base,
      lecturas: [lectura(posParada(2) + 100, { precisionM: 100, velocidadKmh: 40 })],
      proveedor: proveedorFijo({ duracionS: 120 }),
    });
    expect(r.etaMin).toBeCloseTo(2, 6);
  });
  it('velocidad desconocida (null): usa solo la duración vial', async () => {
    const r = await calcularEta({ ...base, lecturas: [lectura(posParada(2) + 100, { velocidadKmh: null })], proveedor: proveedorFijo({ duracionS: 90 }) });
    expect(r.etaMin).toBeCloseTo(1.5, 6);
  });
  it('marca esSimulado cuando la lectura es simulada', async () => {
    const r = await calcularEta({ ...base, lecturas: [lectura(posParada(2) + 100, { origen: 'simulado' })], proveedor: proveedorFijo() });
    expect(r.esSimulado).toBe(true);
  });
});

describe('calcularEta · respaldo cuando falla el proveedor', () => {
  it('usa distancia por trazado ÷ velocidad suavizada del vehículo y lo declara', async () => {
    const m = posParada(2) + 100;
    const r = await calcularEta({ ...base, lecturas: [lectura(m, { velocidadKmh: 20 })], proveedor: proveedorQueFalla });
    expect(r.estado).toBe('ok');
    expect(r.fuenteCalculo).toBe('respaldo_ruta');
    const distancia = posParada(3) - m;
    expect(r.distanciaRestanteM).toBeCloseTo(distancia, 0);
    expect(r.etaMin).toBeCloseTo((distancia / 1000 / 20) * 60, 1);
    expect(r.advertencias.join(' ')).toMatch(/no disponible/);
  });
  it('sin proveedor configurado también usa el respaldo', async () => {
    const r = await calcularEta({ ...base, lecturas: [lectura(posParada(2) + 100)], proveedor: null });
    expect(r.fuenteCalculo).toBe('respaldo_ruta');
  });
  it('sin velocidad confiable usa la velocidad de respaldo configurada y avisa del supuesto', async () => {
    const m = posParada(2) + 100;
    const r = await calcularEta({ ...base, lecturas: [lectura(m, { velocidadKmh: null })], proveedor: proveedorQueFalla });
    const distancia = posParada(3) - m;
    expect(r.etaMin).toBeCloseTo((distancia / 1000 / CONFIG_ETA_POR_DEFECTO.velocidadRespaldoKmh) * 60, 1);
    expect(r.advertencias.join(' ')).toMatch(/supuesto/);
  });
  it('es determinista: misma entrada → mismo resultado', async () => {
    const e = { ...base, lecturas: [lectura(500)], proveedor: proveedorQueFalla };
    const a = await calcularEta(e);
    const b = await calcularEta(e);
    expect(a.etaMin).toBe(b.etaMin);
  });
});

describe('velocidad', () => {
  it('suavizado exponencial con alfa 0.4', () => {
    const v = suavizarVelocidadKmh([
      { velocidadKmh: 10, precisionM: 5 },
      { velocidadKmh: 20, precisionM: 5 },
    ]);
    expect(v).toBeCloseTo(0.4 * 20 + 0.6 * 10, 10);
  });
  it('ignora lecturas con velocidad nula, absurda o imprecisa', () => {
    expect(
      suavizarVelocidadKmh([
        { velocidadKmh: null, precisionM: 5 },
        { velocidadKmh: 500, precisionM: 5 },
        { velocidadKmh: 30, precisionM: 200 },
      ]),
    ).toBeNull();
  });
  it('detenida / confiable / tráfico', () => {
    expect(estaDetenida(1)).toBe(true);
    expect(estaDetenida(10)).toBe(false);
    expect(estaDetenida(null)).toBe(false);
    expect(velocidadEsConfiable({ velocidadKmh: -1, precisionM: 5 })).toBe(false);
    expect(clasificarCondicionTrafico(28, 30)).toBe('fluido');
    expect(clasificarCondicionTrafico(15, 30)).toBe('moderado');
    expect(clasificarCondicionTrafico(5, 30)).toBe('denso');
    expect(clasificarCondicionTrafico(null, 30)).toBe('desconocido');
  });
});
