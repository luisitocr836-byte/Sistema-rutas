import { validarCoordenadas } from './geo';
import type { Coordenada, FuenteDatos } from './types';

/**
 * Lectura y validación de los GeoJSON de rutas (formato definido en datos-espaciales/LEEME.md).
 * Reglas:
 *  - GeoJSON usa [longitud, latitud] (RFC 7946); aquí se convierte a { latitud, longitud }.
 *  - Debe haber UNA Feature LineString con properties.tipo = "ruta".
 *  - Las paradas son Features Point con properties.tipo = "parada" y orden_secuencia entero único.
 *  - properties.fuente_datos es OBLIGATORIA en la ruta: evita presentar datos demostrativos como oficiales.
 */

export interface ParadaImportada extends Coordenada {
  ordenSecuencia: number;
  nombre: string;
  referenciaVial: string | null;
  esNodoTransferencia: boolean;
}

export interface RutaImportada {
  numeroRuta: string;
  nombre: string;
  origen: string;
  destino: string;
  colorHex: string | null;
  horarioInicio: string | null;
  horarioFin: string | null;
  frecuenciaPromedioMin: number | null;
  fuenteDatos: FuenteDatos;
  advertencia: string | null;
  trazado: Coordenada[];
  paradas: ParadaImportada[];
}

const FUENTES: FuenteDatos[] = ['oficial', 'levantamiento_equipo', 'demostracion'];

type Props = Record<string, unknown>;

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

function textoObligatorio(p: Props, clave: string, contexto: string): string {
  const v = p[clave];
  if (typeof v !== 'string' || v.trim() === '') {
    throw new Error(`${contexto}: falta la propiedad de texto "${clave}".`);
  }
  return v.trim();
}

function textoOpcional(p: Props, clave: string): string | null {
  const v = p[clave];
  return typeof v === 'string' && v.trim() !== '' ? v.trim() : null;
}

function aCoordenada(par: unknown, contexto: string): Coordenada {
  if (!Array.isArray(par) || par.length < 2) {
    throw new Error(`${contexto}: cada coordenada debe ser [longitud, latitud].`);
  }
  const [lon, lat] = par as unknown[];
  const v = validarCoordenadas(lat, lon);
  if (!v.valido) throw new Error(`${contexto}: ${v.motivo} (valor recibido: [${String(lon)}, ${String(lat)}]).`);
  return { latitud: lat as number, longitud: lon as number };
}

export function parsearRutaGeoJson(data: unknown): RutaImportada {
  if (!esObjeto(data) || data.type !== 'FeatureCollection' || !Array.isArray(data.features)) {
    throw new Error('El archivo debe ser un GeoJSON de tipo FeatureCollection.');
  }
  const features = data.features.filter(esObjeto);

  const rutas = features.filter((f) => esObjeto(f.geometry) && f.geometry.type === 'LineString');
  if (rutas.length !== 1) {
    throw new Error(`Se esperaba exactamente 1 Feature LineString (trazado) y se encontraron ${rutas.length}.`);
  }
  const fr = rutas[0];
  const pr: Props = esObjeto(fr.properties) ? fr.properties : {};
  const geom = fr.geometry as Record<string, unknown>;
  if (!Array.isArray(geom.coordinates) || geom.coordinates.length < 2) {
    throw new Error('El trazado necesita al menos 2 vértices.');
  }
  const trazado = geom.coordinates.map((c, i) => aCoordenada(c, `Trazado, vértice ${i + 1}`));

  const fuente = pr.fuente_datos;
  if (typeof fuente !== 'string' || !FUENTES.includes(fuente as FuenteDatos)) {
    throw new Error(`La ruta debe declarar properties.fuente_datos con uno de: ${FUENTES.join(', ')}.`);
  }

  const frecuencia = pr.frecuencia_promedio_min;
  if (frecuencia !== null && frecuencia !== undefined && !(typeof frecuencia === 'number' && Number.isInteger(frecuencia) && frecuencia > 0)) {
    throw new Error('frecuencia_promedio_min debe ser un entero positivo o null.');
  }
  const color = textoOpcional(pr, 'color_hex');
  if (color !== null && !/^#[0-9A-Fa-f]{6}$/.test(color)) {
    throw new Error('color_hex debe tener el formato #RRGGBB.');
  }

  const puntos = features.filter((f) => esObjeto(f.geometry) && f.geometry.type === 'Point');
  const paradas: ParadaImportada[] = puntos.map((f, i) => {
    const p: Props = esObjeto(f.properties) ? f.properties : {};
    const ctx = `Parada #${i + 1}`;
    const orden = p.orden_secuencia;
    if (typeof orden !== 'number' || !Number.isInteger(orden) || orden <= 0) {
      throw new Error(`${ctx}: orden_secuencia debe ser un entero positivo.`);
    }
    const c = aCoordenada((f.geometry as Record<string, unknown>).coordinates, ctx);
    return {
      ...c,
      ordenSecuencia: orden,
      nombre: textoObligatorio(p, 'nombre', ctx),
      referenciaVial: textoOpcional(p, 'referencia_vial'),
      esNodoTransferencia: p.es_nodo_transferencia === true,
    };
  });
  const ordenes = new Set(paradas.map((p) => p.ordenSecuencia));
  if (ordenes.size !== paradas.length) throw new Error('Hay paradas con orden_secuencia repetido.');
  paradas.sort((a, b) => a.ordenSecuencia - b.ordenSecuencia);

  return {
    numeroRuta: textoObligatorio(pr, 'numero_ruta', 'Ruta'),
    nombre: textoObligatorio(pr, 'nombre', 'Ruta'),
    origen: textoObligatorio(pr, 'origen', 'Ruta'),
    destino: textoObligatorio(pr, 'destino', 'Ruta'),
    colorHex: color,
    horarioInicio: textoOpcional(pr, 'horario_inicio'),
    horarioFin: textoOpcional(pr, 'horario_fin'),
    frecuenciaPromedioMin: typeof frecuencia === 'number' ? frecuencia : null,
    fuenteDatos: fuente as FuenteDatos,
    advertencia: textoOpcional(pr, 'advertencia'),
    trazado,
    paradas,
  };
}

/** WKT en orden (longitud latitud), listo para ST_GeomFromText(..., 4326). */
export function trazadoAWkt(trazado: Coordenada[]): string {
  return `LINESTRING(${trazado.map((c) => `${c.longitud} ${c.latitud}`).join(', ')})`;
}

/** Convierte una geometría GeoJSON LineString (p. ej. columna trazado_geojson de v_rutas) a coordenadas. */
export function lineStringGeoJsonACoordenadas(geojson: unknown): Coordenada[] {
  if (!esObjeto(geojson) || geojson.type !== 'LineString' || !Array.isArray(geojson.coordinates)) {
    throw new Error('Se esperaba una geometría GeoJSON LineString.');
  }
  return geojson.coordinates.map((c, i) => aCoordenada(c, `Vértice ${i + 1}`));
}
