/**
 * Simulador GPS de MoviQro: desplaza una unidad DEMOSTRATIVA por una ruta piloto.
 * Toda posición se marca origen_dato = 'simulado' (nunca se mezcla con datos reales).
 *
 * Modos:
 *   --seco     No usa Supabase: imprime posiciones y el ETA calculado con el respaldo por trazado.
 *   (defecto)  Inserta en coordenadas_log con la clave service_role (SOLO servidor de confianza).
 *
 * Uso (desde /backend):
 *   npm run simulador -- --ruta=38 --seco --pasos=20
 *   npm run simulador -- --ruta=38 --velocidad=30 --intervalo=4 --aceleracion=1 --bucle
 *
 * Opciones: --ruta=<numero_ruta> (38) · --velocidad=<km/h> (30) · --intervalo=<s reales entre envíos> (4)
 *           --aceleracion=<factor de tiempo simulado> (1) · --bucle · --pasos=<máx. envíos> · --seco
 */
import 'dotenv/config';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { RUTAS_LOCALES } from '../core/rutasLocales';
import { SimuladorUnidad, calcularEta, validarCoordenadas } from '../core';

function opcion(nombre: string, porDefecto: string): string {
  const a = process.argv.find((x) => x.startsWith(`--${nombre}=`));
  return a ? a.split('=')[1] : porDefecto;
}
const bandera = (n: string) => process.argv.includes(`--${n}`);
const espera = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const numeroRuta = opcion('ruta', '38');
  const velocidad = Number(opcion('velocidad', '30'));
  const intervalo = Number(opcion('intervalo', '4'));
  const aceleracion = Number(opcion('aceleracion', '1'));
  const maxPasos = Number(opcion('pasos', '0')); // 0 = sin límite
  const seco = bandera('seco');
  const bucle = bandera('bucle');
  if (![velocidad, intervalo, aceleracion].every((n) => Number.isFinite(n) && n > 0)) {
    throw new Error('--velocidad, --intervalo y --aceleracion deben ser números > 0.');
  }

  const local = RUTAS_LOCALES.find((r) => r.ruta.numeroRuta === numeroRuta);
  if (!local) throw new Error(`Ruta "${numeroRuta}" no existe en datos-espaciales (disponibles: ${RUTAS_LOCALES.map((r) => r.ruta.numeroRuta).join(', ')}).`);
  console.log(`Simulador GPS · ruta ${numeroRuta} (${local.ruta.fuenteDatos}) · ${velocidad} km/h · cada ${intervalo} s · ${seco ? 'MODO SECO (sin Supabase)' : 'Supabase'}`);
  if (local.ruta.fuenteDatos === 'demostracion') console.log('Datos de ruta DEMOSTRATIVOS. Las posiciones se marcan como simuladas.');

  let db: SupabaseClient | null = null;
  let idUnidad = 0;
  if (!seco) {
    const url = process.env.SUPABASE_URL;
    const llave = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !llave) throw new Error('Faltan SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY en .env (o use --seco).');
    db = createClient(url, llave, { auth: { persistSession: false } });
    const { data, error } = await db.from('unidades').select('id_unidad').eq('numero_economico', `DEMO-R${numeroRuta}-01`).maybeSingle();
    if (error) throw new Error(`No se pudo buscar la unidad: ${error.message}`);
    if (!data) throw new Error(`No existe la unidad DEMO-R${numeroRuta}-01. Ejecute backend-sql/seeds/002_unidades_e_incidencias_demo.sql.`);
    idUnidad = (data as { id_unidad: number }).id_unidad;
  }

  const sim = new SimuladorUnidad({ trazado: local.ruta.trazado, velocidadKmh: velocidad, intervaloS: intervalo * aceleracion, bucle }, Date.now());
  const historial: ReturnType<SimuladorUnidad['actual']>[] = [];
  let paso = 0;

  while (!sim.terminado && (maxPasos === 0 || paso < maxPasos)) {
    const l = { ...(paso === 0 ? sim.actual() : sim.avanzar()), timestampMs: Date.now() };
    paso++;
    const v = validarCoordenadas(l.latitud, l.longitud);
    if (!v.valido) throw new Error(`Posición simulada inválida: ${v.motivo}`);
    historial.push(l);
    if (historial.length > 8) historial.shift();

    let nota = '';
    if (seco) {
      const eta = await calcularEta({ lecturas: historial, trazado: local.ruta.trazado, paradas: local.paradas, proveedor: null, ahoraMs: Date.now() });
      nota = eta.estado === 'ok' ? ` → ${eta.paradaObjetivo?.nombre}: ETA ${eta.etaMin?.toFixed(2)} min (${eta.fuenteCalculo}, ${eta.distanciaRestanteM?.toFixed(0)} m)` : ` → ${eta.mensaje}`;
    } else if (db) {
      const { error } = await db.from('coordenadas_log').insert({
        id_unidad: idUnidad,
        latitud: l.latitud,
        longitud: l.longitud,
        velocidad_kmh: l.velocidadKmh,
        precision_gps_m: l.precisionM,
        fecha_hora: new Date(l.timestampMs).toISOString(),
        origen_dato: 'simulado',
      });
      nota = error ? ` ✖ error al insertar: ${error.message}` : ' ✔ insertado';
    }
    console.log(`#${String(paso).padStart(3)} ${l.latitud.toFixed(5)}, ${l.longitud.toFixed(5)} · ${l.velocidadKmh} km/h · simulado${nota}`);
    if (!seco) await espera(intervalo * 1000);
  }
  console.log(sim.terminado ? 'Recorrido terminado.' : 'Detenido por --pasos.');
}

main().catch((e) => {
  console.error(`Simulador detenido: ${e instanceof Error ? e.message : String(e)}`);
  process.exit(1);
});
