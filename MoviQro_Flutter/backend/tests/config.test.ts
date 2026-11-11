import { describe, expect, it } from 'vitest';
import { ProveedorOsrm } from '../core';
import { cargarConfigWorker, crearProveedor } from '../src/config';

const envOk = { SUPABASE_URL: 'https://ejemplo.supabase.co', SUPABASE_SERVICE_ROLE_KEY: 'clave-de-prueba' };

describe('cargarConfigWorker', () => {
  it('valores por defecto: proveedor osrm e intervalo 5 s', () => {
    const c = cargarConfigWorker(envOk);
    expect(c.proveedor).toBe('osrm');
    expect(c.intervaloMinimoS).toBe(5);
    expect(crearProveedor(c)).toBeInstanceOf(ProveedorOsrm);
  });
  it('exige SUPABASE_URL y la llave de servicio', () => {
    expect(() => cargarConfigWorker({})).toThrow(/SUPABASE_URL/);
    expect(() => cargarConfigWorker({ SUPABASE_URL: 'https://x.supabase.co' })).toThrow(/SERVICE_ROLE/);
  });
  it('ETA_PROVIDER=none desactiva el proveedor (solo respaldo)', () => {
    expect(crearProveedor(cargarConfigWorker({ ...envOk, ETA_PROVIDER: 'none' }))).toBeNull();
  });
  it('google requiere clave', () => {
    expect(() => cargarConfigWorker({ ...envOk, ETA_PROVIDER: 'google' })).toThrow(/GOOGLE_MAPS_API_KEY/);
  });
  it('valida rangos numéricos', () => {
    expect(() => cargarConfigWorker({ ...envOk, ETA_PESO_PROVEEDOR: '2' })).toThrow(/ETA_PESO_PROVEEDOR/);
    expect(() => cargarConfigWorker({ ...envOk, ETA_INTERVALO_MINIMO_S: 'abc' })).toThrow(/ETA_INTERVALO_MINIMO_S/);
  });
  it('el mensaje de error no filtra la llave de servicio', () => {
    try {
      cargarConfigWorker({ ...envOk, ETA_PROVIDER: 'otro' });
    } catch (e) {
      expect(String(e)).not.toContain('clave-de-prueba');
    }
  });
});
