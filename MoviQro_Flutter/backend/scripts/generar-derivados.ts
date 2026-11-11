/**
 * Genera, a partir de datos-espaciales/ruta_*.geojson (única fuente de verdad):
 *   1) backend-sql/seeds/001_rutas_y_paradas.sql   (carga reproducible en Supabase)
 *   2) app-flutter/lib/datos/rutas_locales.dart    (datos locales de la app para el modo de demostración)
 *   3) backend/core/rutasLocales.ts                (los mismos datos para el simulador y las pruebas)
 *
 * Uso:  npm run datos:generar
 */
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parsearRutaGeoJson, trazadoAWkt, type RutaImportada } from '../core/geojson';

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const dirDatos = join(raiz, 'datos-espaciales');

const sq = (s: string | null) => (s === null ? 'null' : `'${s.replace(/'/g, "''")}'`);

function cargarRutas(): { archivo: string; ruta: RutaImportada }[] {
  const archivos = readdirSync(dirDatos).filter((f) => /^ruta_.*\.geojson$/.test(f)).sort();
  if (archivos.length === 0) throw new Error(`No hay archivos ruta_*.geojson en ${dirDatos}`);
  return archivos.map((archivo) => {
    try {
      return { archivo, ruta: parsearRutaGeoJson(JSON.parse(readFileSync(join(dirDatos, archivo), 'utf8'))) };
    } catch (e) {
      throw new Error(`${archivo}: ${e instanceof Error ? e.message : String(e)}`);
    }
  });
}

function generarSeedSql(rutas: { archivo: string; ruta: RutaImportada }[]): string {
  const hayDemo = rutas.some((r) => r.ruta.fuenteDatos === 'demostracion');
  const out: string[] = [];
  out.push('-- =====================================================================');
  out.push('-- MoviQro · Semilla de rutas y paradas');
  out.push('-- GENERADO por backend/scripts/generar-derivados.ts a partir de datos-espaciales/*.geojson.');
  out.push('-- No editar a mano: edite el GeoJSON y ejecute `npm run datos:generar`.');
  if (hayDemo) {
    out.push('--');
    out.push('-- ⚠ CONTIENE DATOS DEMOSTRATIVOS (fuente_datos = demostracion). Trazados y paradas');
    out.push('--   ilustrativos; NO son los recorridos oficiales. Reemplazar por los GeoJSON del Avance 1.');
  }
  out.push('-- Orden de coordenadas: (longitud latitud). SRID 4326.');
  out.push('-- Idempotente: se puede ejecutar varias veces.');
  out.push('-- =====================================================================');
  out.push('set search_path = public, extensions;');
  out.push('');
  for (const { archivo, ruta } of rutas) {
    out.push(`-- ${archivo} · fuente_datos=${ruta.fuenteDatos}`);
    out.push(
      `insert into public.rutas (numero_ruta, nombre, origen, destino, color_hex, horario_inicio, horario_fin, frecuencia_promedio_min, trazado, fuente_datos)\n` +
        `values (${sq(ruta.numeroRuta)}, ${sq(ruta.nombre)}, ${sq(ruta.origen)}, ${sq(ruta.destino)}, ${sq(ruta.colorHex)}, ${sq(ruta.horarioInicio)}, ${sq(ruta.horarioFin)}, ${ruta.frecuenciaPromedioMin ?? 'null'},\n` +
        `        ST_GeomFromText('${trazadoAWkt(ruta.trazado)}', 4326), ${sq(ruta.fuenteDatos)})\n` +
        `on conflict (numero_ruta) do update set nombre = excluded.nombre, origen = excluded.origen, destino = excluded.destino,\n` +
        `  color_hex = excluded.color_hex, horario_inicio = excluded.horario_inicio, horario_fin = excluded.horario_fin,\n` +
        `  frecuencia_promedio_min = excluded.frecuencia_promedio_min, trazado = excluded.trazado, fuente_datos = excluded.fuente_datos;`,
    );
    out.push(
      `update public.rutas set distancia_km = round((ST_Length(trazado::geography) / 1000.0)::numeric, 3) where numero_ruta = ${sq(ruta.numeroRuta)};`,
    );
    for (const p of ruta.paradas) {
      out.push(
        `insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)\n` +
          `select r.id_ruta, ${sq(p.nombre)}, ${sq(p.referenciaVial)}, ${p.ordenSecuencia}, ${p.esNodoTransferencia}, ST_SetSRID(ST_MakePoint(${p.longitud}, ${p.latitud}), 4326), ${sq(ruta.fuenteDatos)}\n` +
          `  from public.rutas r where r.numero_ruta = ${sq(ruta.numeroRuta)}\n` +
          `on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,\n` +
          `  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;`,
      );
    }
    out.push('');
  }
  return out.join('\n');
}

function construirDatos(rutas: { archivo: string; ruta: RutaImportada }[]) {
  let idParada = 1;
  return rutas.map(({ ruta }, i) => ({
    ruta: {
      idRuta: i + 1,
      numeroRuta: ruta.numeroRuta,
      nombre: ruta.nombre,
      origen: ruta.origen,
      destino: ruta.destino,
      distanciaKm: null as number | null,
      colorHex: ruta.colorHex,
      horarioInicio: ruta.horarioInicio,
      horarioFin: ruta.horarioFin,
      frecuenciaPromedioMin: ruta.frecuenciaPromedioMin,
      activa: true,
      trazado: ruta.trazado,
      fuenteDatos: ruta.fuenteDatos,
    },
    paradas: ruta.paradas.map((p) => ({
      idParada: idParada++,
      idRuta: i + 1,
      nombre: p.nombre,
      referenciaVial: p.referenciaVial,
      ordenSecuencia: p.ordenSecuencia,
      esNodoTransferencia: p.esNodoTransferencia,
      latitud: p.latitud,
      longitud: p.longitud,
    })),
  }));
}

function generarDatosTs(rutas: { archivo: string; ruta: RutaImportada }[]): string {
  return (
    `/* AUTOGENERADO por backend/scripts/generar-derivados.ts desde datos-espaciales/*.geojson. No editar a mano.\n` +
    ` * Si fuenteDatos === 'demostracion' los trazados y paradas son ILUSTRATIVOS, no oficiales. */\n` +
    `import type { Parada, Ruta } from './types';\n\n` +
    `export interface RutaLocal {\n  ruta: Ruta;\n  paradas: Parada[];\n}\n\n` +
    `export const RUTAS_LOCALES: RutaLocal[] = ${JSON.stringify(construirDatos(rutas), null, 2)};\n`
  );
}

const dq = (s: string | null) => (s === null ? 'null' : JSON.stringify(s).replace(/\$/g, '\\$'));
const dn = (n: number | null) => (n === null ? 'null' : Number.isInteger(n) ? `${n}.0` : String(n));

function generarDatosDart(rutas: { archivo: string; ruta: RutaImportada }[]): string {
  const filas: string[] = [];
  for (const { ruta, paradas } of construirDatos(rutas)) {
    const trazado = ruta.trazado.map((c) => `      Coordenada(${dn(c.latitud)}, ${dn(c.longitud)}),`).join('\n');
    const ps = paradas
      .map(
        (p) =>
          `      Parada(idParada: ${p.idParada}, idRuta: ${p.idRuta}, nombre: ${dq(p.nombre)}, referenciaVial: ${dq(p.referenciaVial)}, ` +
          `ordenSecuencia: ${p.ordenSecuencia}, esNodoTransferencia: ${p.esNodoTransferencia}, latitud: ${dn(p.latitud)}, longitud: ${dn(p.longitud)}),`,
      )
      .join('\n');
    filas.push(
      `  RutaConParadas(\n    ruta: Ruta(\n      idRuta: ${ruta.idRuta}, numeroRuta: ${dq(ruta.numeroRuta)}, nombre: ${dq(ruta.nombre)},\n` +
        `      origen: ${dq(ruta.origen)}, destino: ${dq(ruta.destino)}, distanciaKm: ${dn(ruta.distanciaKm)}, colorHex: ${dq(ruta.colorHex)},\n` +
        `      horarioInicio: ${dq(ruta.horarioInicio)}, horarioFin: ${dq(ruta.horarioFin)}, frecuenciaPromedioMin: ${ruta.frecuenciaPromedioMin ?? 'null'},\n` +
        `      activa: true, fuenteDatos: FuenteDatos.${ruta.fuenteDatos},\n      trazado: [\n${trazado}\n      ],\n    ),\n    paradas: [\n${ps}\n    ],\n  ),`,
    );
  }
  return (
    `// AUTOGENERADO por backend/scripts/generar-derivados.ts desde datos-espaciales/*.geojson. No editar a mano.\n` +
    `// Si fuenteDatos == demostracion, los trazados y paradas son ILUSTRATIVOS, no oficiales.\n` +
    `import '../core/tipos.dart';\n\nfinal List<RutaConParadas> rutasLocales = [\n${filas.join('\n')}\n];\n`
  );
}

const rutas = cargarRutas();
writeFileSync(join(raiz, 'backend-sql', 'seeds', '001_rutas_y_paradas.sql'), generarSeedSql(rutas));
writeFileSync(join(raiz, 'backend', 'core', 'rutasLocales.ts'), generarDatosTs(rutas));
writeFileSync(join(raiz, 'app-flutter', 'lib', 'datos', 'rutas_locales.dart'), generarDatosDart(rutas));
console.log(`Generado: ${rutas.length} ruta(s): ${rutas.map((r) => r.ruta.numeroRuta).join(', ')}`);
