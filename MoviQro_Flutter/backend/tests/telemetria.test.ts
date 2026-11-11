import { describe, expect, it } from 'vitest';
import { BufferTelemetria, aFilaCoordenadasLog, type LecturaGps } from '../core';
import { AHORA, lectura } from './helpers';

const l = (i: number): LecturaGps => lectura(i * 10, { timestampMs: AHORA + i });

describe('BufferTelemetria (hasta 20 posiciones)', () => {
  it('capacidad por defecto 20; al desbordar descarta las más antiguas', () => {
    const b = new BufferTelemetria();
    for (let i = 0; i < 25; i++) b.agregar(l(i));
    expect(b.tamano).toBe(20);
    expect(b.descartadas).toBe(5);
    expect(b.instantanea()[0].timestampMs).toBe(AHORA + 5);
  });
  it('envía en ráfaga y queda vacío', async () => {
    const b = new BufferTelemetria();
    [1, 2, 3].forEach((i) => b.agregar(l(i)));
    let recibido: LecturaGps[] = [];
    const r = await b.vaciar(async (lote) => { recibido = lote; });
    expect(r).toEqual({ enviadas: 3 });
    expect(recibido).toHaveLength(3);
    expect(b.tamano).toBe(0);
  });
  it('si el envío falla conserva las lecturas y reporta el error; luego reintenta con éxito', async () => {
    const b = new BufferTelemetria();
    [1, 2].forEach((i) => b.agregar(l(i)));
    const fallo = await b.vaciar(async () => { throw new Error('sin red'); });
    expect(fallo.enviadas).toBe(0);
    expect(fallo.error).toBe('sin red');
    expect(b.tamano).toBe(2);
    b.agregar(l(3));
    let n = 0;
    const ok = await b.vaciar(async (lote) => { n = lote.length; });
    expect(ok.enviadas).toBe(3);
    expect(n).toBe(3);
  });
  it('lecturas que llegan durante un envío fallido se conservan en orden', async () => {
    const b = new BufferTelemetria();
    b.agregar(l(1));
    await b.vaciar(async () => {
      b.agregar(l(2));
      throw new Error('x');
    });
    expect(b.instantanea().map((x) => x.timestampMs)).toEqual([AHORA + 1, AHORA + 2]);
  });
  it('no permite dos envíos simultáneos', async () => {
    const b = new BufferTelemetria();
    b.agregar(l(1));
    let liberar: () => void = () => undefined;
    const primero = b.vaciar(() => new Promise<void>((res) => { liberar = res; }));
    const segundo = await b.vaciar(async () => undefined);
    expect(segundo.enviadas).toBe(0);
    liberar();
    expect((await primero).enviadas).toBe(1);
  });
  it('capacidad inválida lanza', () => {
    expect(() => new BufferTelemetria(0)).toThrow();
  });
});

describe('aFilaCoordenadasLog', () => {
  it('genera la fila con fecha ISO, origen y valores redondeados', () => {
    const fila = aFilaCoordenadasLog(7, { latitud: 20.3889, longitud: -99.9961, velocidadKmh: 25.12345, precisionM: 6.5, timestampMs: AHORA, origen: 'real' });
    expect(fila).toMatchObject({ id_unidad: 7, latitud: 20.3889, longitud: -99.9961, velocidad_kmh: 25.12, precision_gps_m: 6.5, origen_dato: 'real' });
    expect(fila.fecha_hora).toBe(new Date(AHORA).toISOString());
  });
  it('rechaza coordenadas inválidas, velocidad fuera de rango y unidad inválida', () => {
    const base: LecturaGps = { latitud: 20.38, longitud: -99.98, velocidadKmh: 10, precisionM: 5, timestampMs: AHORA, origen: 'real' };
    expect(() => aFilaCoordenadasLog(1, { ...base, latitud: 0, longitud: 0 })).toThrow();
    expect(() => aFilaCoordenadasLog(1, { ...base, velocidadKmh: 300 })).toThrow(/Velocidad/);
    expect(() => aFilaCoordenadasLog(0, base)).toThrow(/unidad/);
    expect(() => aFilaCoordenadasLog(1, { ...base, timestampMs: NaN })).toThrow(/tiempo/);
  });
  it('velocidad y precisión nulas se conservan como null', () => {
    const fila = aFilaCoordenadasLog(1, { latitud: 20.38, longitud: -99.98, velocidadKmh: null, precisionM: null, timestampMs: AHORA, origen: 'simulado' });
    expect(fila.velocidad_kmh).toBeNull();
    expect(fila.precision_gps_m).toBeNull();
    expect(fila.origen_dato).toBe('simulado');
  });
});
