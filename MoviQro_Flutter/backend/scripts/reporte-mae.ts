/**
 * Reporte de validación del ETA: MAE, MAPE y nº de observaciones válidas desde Supabase.
 *   npm run validacion:mae [-- --ruta=<id_ruta>] [--incluir-simulados]
 * Por defecto EXCLUYE estimaciones simuladas. Reporta únicamente lo que existe en la base de datos.
 */
import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
import { calcularMAE } from '../core';
import { RepositorioSupabase } from '../src/repositorio';

const OBJETIVO_RECORRIDOS = 100; // Avance 2, "Plan para la siguiente fase"

async function main() {
  const url = process.env.SUPABASE_URL;
  const llave = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !llave) throw new Error('Faltan SUPABASE_URL y/o SUPABASE_SERVICE_ROLE_KEY en el entorno (.env).');
  const argRuta = process.argv.find((a) => a.startsWith('--ruta='));
  const idRuta = argRuta ? Number(argRuta.split('=')[1]) : undefined;
  if (idRuta !== undefined && !Number.isInteger(idRuta)) throw new Error('--ruta debe ser un entero.');
  const incluirSimulados = process.argv.includes('--incluir-simulados');

  const repo = new RepositorioSupabase(createClient(url, llave, { auth: { persistSession: false } }));
  const r = calcularMAE(await repo.obtenerObservaciones(idRuta, incluirSimulados));

  console.log(`Observaciones válidas: ${r.n} (descartadas: ${r.descartadas})${incluirSimulados ? ' [incluye simuladas]' : ' [solo datos reales]'}`);
  if (r.n === 0) {
    console.log('Sin observaciones con tiempo real: aún no se puede calcular el MAE.');
    return;
  }
  console.log(`MAE:  ${r.maeMin?.toFixed(3)} min`);
  console.log(`MAPE: ${r.mapePct?.toFixed(2)} %`);
  console.log(`Error máximo: ${r.maxErrorMin?.toFixed(3)} min`);
  if (r.n < OBJETIVO_RECORRIDOS) {
    console.log(`Nota: el plan del Avance 2 prevé ≥ ${OBJETIVO_RECORRIDOS} recorridos reales; con n=${r.n} el MAE no es concluyente.`);
  }
}

main().catch((e) => {
  console.error(`Reporte fallido: ${e instanceof Error ? e.message : String(e)}`);
  process.exit(1);
});
