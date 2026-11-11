import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';
import { lineStringGeoJsonACoordenadas, parsearRutaGeoJson, trazadoAWkt } from '../core';

const leer = (f: string) => JSON.parse(readFileSync(resolve(__dirname, '../../datos-espaciales', f), 'utf8'));

const minimo = () => ({
  type: 'FeatureCollection',
  features: [
    { type: 'Feature', properties: { tipo: 'ruta', numero_ruta: '99', nombre: 'X', origen: 'A', destino: 'B', fuente_datos: 'demostracion' }, geometry: { type: 'LineString', coordinates: [[-99.99, 20.38], [-99.98, 20.39]] } },
    { type: 'Feature', properties: { tipo: 'parada', orden_secuencia: 1, nombre: 'P1' }, geometry: { type: 'Point', coordinates: [-99.99, 20.38] } },
  ],
});

describe('GeoJSON de rutas incluidos en el proyecto', () => {
  it.each(['ruta_38.geojson', 'ruta_39.geojson'])('%s es válido y está identificado como demostración', (archivo) => {
    const r = parsearRutaGeoJson(leer(archivo));
    expect(r.trazado.length).toBeGreaterThanOrEqual(2);
    expect(r.paradas.length).toBeGreaterThanOrEqual(2);
    expect(r.fuenteDatos).toBe('demostracion');
    expect(r.advertencia).toMatch(/DEMOSTRATIVOS/);
    r.paradas.forEach((p, i) => expect(p.ordenSecuencia).toBe(i + 1));
  });
});

describe('parsearRutaGeoJson · validaciones', () => {
  it('convierte [lon, lat] a { latitud, longitud }', () => {
    const r = parsearRutaGeoJson(minimo());
    expect(r.trazado[0]).toEqual({ latitud: 20.38, longitud: -99.99 });
  });
  it('rechaza si no es FeatureCollection', () => {
    expect(() => parsearRutaGeoJson({ type: 'Feature' })).toThrow(/FeatureCollection/);
    expect(() => parsearRutaGeoJson(null)).toThrow();
  });
  it('rechaza coordenadas invertidas (lat/lon) con mensaje claro', () => {
    const d = minimo();
    (d.features[0].geometry as { coordinates: number[][] }).coordinates[0] = [20.38, -99.99];
    expect(() => parsearRutaGeoJson(d)).toThrow(/vértice 1/);
  });
  it('exige fuente_datos explícita (no se asume oficial)', () => {
    const d = minimo();
    delete (d.features[0].properties as Record<string, unknown>).fuente_datos;
    expect(() => parsearRutaGeoJson(d)).toThrow(/fuente_datos/);
  });
  it('rechaza órdenes de parada repetidos', () => {
    const d = minimo();
    d.features.push(structuredClone(d.features[1]));
    expect(() => parsearRutaGeoJson(d)).toThrow(/repetido/);
  });
  it('rechaza trazado con menos de 2 vértices', () => {
    const d = minimo();
    (d.features[0].geometry as { coordinates: number[][] }).coordinates = [[-99.99, 20.38]];
    expect(() => parsearRutaGeoJson(d)).toThrow(/al menos 2/);
  });
});

describe('WKT y conversión de GeoJSON de la base de datos', () => {
  it('trazadoAWkt usa orden (longitud latitud)', () => {
    expect(trazadoAWkt([{ latitud: 20.38, longitud: -99.99 }, { latitud: 20.39, longitud: -99.98 }])).toBe('LINESTRING(-99.99 20.38, -99.98 20.39)');
  });
  it('lineStringGeoJsonACoordenadas', () => {
    expect(lineStringGeoJsonACoordenadas({ type: 'LineString', coordinates: [[-99.99, 20.38], [-99.98, 20.39]] })[1]).toEqual({ latitud: 20.39, longitud: -99.98 });
    expect(() => lineStringGeoJsonACoordenadas({ type: 'Point', coordinates: [0, 0] })).toThrow();
  });
});
