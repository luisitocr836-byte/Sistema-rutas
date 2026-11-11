import { describe, expect, it } from 'vitest';
import { ProveedorGoogleDistanceMatrix, ProveedorOsrm, type FetchLike } from '../core';

const origen = { latitud: 20.3889, longitud: -99.9961 };
const destino = { latitud: 20.3851, longitud: -99.982 };

function fetchQueResponde(cuerpo: unknown, ok = true, status = 200): FetchLike & { urls: string[] } {
  const f = (async (url: string) => {
    f.urls.push(url);
    return { ok, status, json: async () => cuerpo };
  }) as FetchLike & { urls: string[] };
  f.urls = [];
  return f;
}

describe('ProveedorOsrm', () => {
  it('envía lon,lat (orden PostGIS) y parsea distancia y duración', async () => {
    const f = fetchQueResponde({ code: 'Ok', routes: [{ distance: 1530.4, duration: 187.2 }] });
    const r = await new ProveedorOsrm('http://osrm.local/', { fetchImpl: f }).obtenerRuta(origen, destino);
    expect(r).toEqual({ distanciaM: 1530.4, duracionS: 187.2, fuente: 'osrm' });
    expect(f.urls[0]).toBe('http://osrm.local/route/v1/driving/-99.9961,20.3889;-99.982,20.3851?overview=false&alternatives=false&steps=false');
  });
  it('error HTTP → lanza', async () => {
    const f = fetchQueResponde({}, false, 503);
    await expect(new ProveedorOsrm('http://osrm.local', { fetchImpl: f }).obtenerRuta(origen, destino)).rejects.toThrow(/503/);
  });
  it('code distinto de Ok o sin rutas → lanza', async () => {
    const f = fetchQueResponde({ code: 'NoRoute', routes: [] });
    await expect(new ProveedorOsrm('http://osrm.local', { fetchImpl: f }).obtenerRuta(origen, destino)).rejects.toThrow(/NoRoute/);
  });
  it('valores inválidos en la respuesta → lanza', async () => {
    const f = fetchQueResponde({ code: 'Ok', routes: [{ distance: 'x', duration: -4 }] });
    await expect(new ProveedorOsrm('http://osrm.local', { fetchImpl: f }).obtenerRuta(origen, destino)).rejects.toThrow(/inválidas/);
  });
  it('tiempo de espera agotado → lanza', async () => {
    const colgado: FetchLike = (_url, init) =>
      new Promise((_res, rej) => init?.signal?.addEventListener('abort', () => rej(new Error('abortado'))));
    await expect(new ProveedorOsrm('http://osrm.local', { fetchImpl: colgado, timeoutMs: 20 }).obtenerRuta(origen, destino)).rejects.toThrow(/Tiempo de espera/);
  });
  it('URL base inválida → lanza al construir', () => {
    expect(() => new ProveedorOsrm('osrm.local')).toThrow();
  });
});

describe('ProveedorGoogleDistanceMatrix', () => {
  const ok = { status: 'OK', rows: [{ elements: [{ status: 'OK', distance: { value: 2000 }, duration: { value: 300 }, duration_in_traffic: { value: 420 } }] }] };
  it('prefiere duration_in_traffic y no expone la clave más allá de la URL de la petición', async () => {
    const f = fetchQueResponde(ok);
    const r = await new ProveedorGoogleDistanceMatrix('CLAVE_DE_PRUEBA', { fetchImpl: f }).obtenerRuta(origen, destino);
    expect(r).toEqual({ distanciaM: 2000, duracionS: 420, fuente: 'google_distance_matrix' });
    expect(f.urls[0]).toContain('origins=20.3889%2C-99.9961');
  });
  it('status distinto de OK → lanza', async () => {
    const f = fetchQueResponde({ status: 'REQUEST_DENIED', rows: [] });
    await expect(new ProveedorGoogleDistanceMatrix('K', { fetchImpl: f }).obtenerRuta(origen, destino)).rejects.toThrow(/REQUEST_DENIED/);
  });
  it('sin clave → lanza', () => {
    expect(() => new ProveedorGoogleDistanceMatrix('')).toThrow();
  });
});
