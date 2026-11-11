/**
 * Importa datos-espaciales/ruta_*.geojson a Supabase (upsert de rutas y paradas).
 * Procedimiento para sustituir los datos demostrativos por los GeoJSON reales del Avance 1:
 *   1) Colocar los archivos (mismo formato; ver datos-espaciales/LEEME.md) en datos-espaciales/.
 *   2) properties.fuente_datos de la ruta debe ser 'oficial' o 'levantamiento_equipo'.
 *   3) npm run datos:importar     (usa SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY del .env)
 * Alternativa sin Supabase JS: `npm run datos:generar` y ejecutar backend-sql/seeds/001_rutas_y_paradas.sql.
 */
import 'dotenv/config';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
import { longitudPolilineaM, parsearRutaGeoJson, trazadoAWkt } from '../core';

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const dir = join(raiz, 'datos-espaciales');

async function main() {
  const url = process.env.SUPABASE_URL;
  const llave = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !llave) throw new Error('Faltan SUPABASE_URL y/o SUPABASE_SERVICE_ROLE_KEY en el entorno (.env).');
  const db = createClient(url, llave, { auth: { persistSession: false } });

  const archivos = readdirSync(dir).filter((f) => /^ruta_.*\.geojson$/.test(f)).sort();
  if (archivos.length === 0) throw new Error(`No hay archivos ruta_*.geojson en ${dir}`);

  for (const archivo of archivos) {
    const ruta = parsearRutaGeoJson(JSON.parse(readFileSync(join(dir, archivo), 'utf8')));
    if (ruta.fuenteDatos === 'demostracion') {
      console.warn(`⚠ ${archivo}: fuente_datos=demostracion (datos ilustrativos, no oficiales).`);
    }
    const { data, error } = await db
      .from('rutas')
      .upsert(
        {
          numero_ruta: ruta.numeroRuta,
          nombre: ruta.nombre,
          origen: ruta.origen,
          destino: ruta.destino,
          color_hex: ruta.colorHex,
          horario_inicio: ruta.horarioInicio,
          horario_fin: ruta.horarioFin,
          frecuencia_promedio_min: ruta.frecuenciaPromedioMin,
          distancia_km: Math.round(longitudPolilineaM(ruta.trazado)) / 1000,
          // EWKT: orden (longitud latitud), SRID 4326
          trazado: `SRID=4326;${trazadoAWkt(ruta.trazado)}`,
          fuente_datos: ruta.fuenteDatos,
        },
        { onConflict: 'numero_ruta' },
      )
      .select('id_ruta')
      .single();
    if (error || !data) throw new Error(`${archivo}: no se pudo guardar la ruta: ${error?.message ?? 'sin datos'}`);

    const filas = ruta.paradas.map((p) => ({
      id_ruta: data.id_ruta,
      nombre: p.nombre,
      referencia_vial: p.referenciaVial,
      orden_secuencia: p.ordenSecuencia,
      es_nodo_transferencia: p.esNodoTransferencia,
      ubicacion: `SRID=4326;POINT(${p.longitud} ${p.latitud})`,
      fuente_datos: ruta.fuenteDatos,
    }));
    const { error: e2 } = await db.from('paradas').upsert(filas, { onConflict: 'id_ruta,orden_secuencia' });
    if (e2) throw new Error(`${archivo}: no se pudieron guardar las paradas: ${e2.message}`);
    console.log(`✔ Ruta ${ruta.numeroRuta}: ${ruta.trazado.length} vértices, ${filas.length} paradas (${ruta.fuenteDatos}).`);
  }
}

main().catch((e) => {
  console.error(`Importación fallida: ${e instanceof Error ? e.message : String(e)}`);
  process.exit(1);
});
