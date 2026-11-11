/**
 * Worker ETA (proceso de servidor).
 * Escucha por Supabase Realtime los INSERT en coordenadas_log y, por cada lectura, calcula y guarda
 * el ETA de la unidad (ServicioEta). Usa la clave service_role: ejecutar SOLO en un servidor de confianza.
 *
 *   cp ../.env.example .env   (completar SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY)
 *   npm run worker
 */
import 'dotenv/config';
import { createClient } from '@supabase/supabase-js';
import { cargarConfigWorker, crearProveedor } from './config';
import { RepositorioSupabase } from './repositorio';
import { ServicioEta } from './servicioEta';

const log = (m: string) => console.log(`${new Date().toISOString()} ${m}`);

async function main() {
  const cfg = cargarConfigWorker(process.env);
  const db = createClient(cfg.supabaseUrl, cfg.supabaseServiceRoleKey, { auth: { persistSession: false } });
  const servicio = new ServicioEta(new RepositorioSupabase(db), {
    proveedor: crearProveedor(cfg),
    config: cfg.eta,
    intervaloMinimoS: cfg.intervaloMinimoS,
    lecturasParaSuavizado: cfg.lecturasParaSuavizado,
    log,
  });

  // Cola simple por unidad para no procesar dos lecturas de la misma unidad a la vez.
  const enCurso = new Set<number>();

  const canal = db
    .channel('worker-eta')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'coordenadas_log' }, async (payload) => {
      const idUnidad = Number((payload.new as { id_unidad?: unknown }).id_unidad);
      if (!Number.isInteger(idUnidad) || enCurso.has(idUnidad)) return;
      enCurso.add(idUnidad);
      try {
        const r = await servicio.procesarUnidad(idUnidad);
        if (r.estado !== 'omitido_por_intervalo') log(`[unidad ${idUnidad}] ${r.estado}: ${r.detalle}`);
        if (r.llegadasRegistradas > 0) log(`[unidad ${idUnidad}] llegada registrada en ${r.llegadasRegistradas} estimación(es).`);
      } catch (e) {
        log(`[unidad ${idUnidad}] ERROR: ${e instanceof Error ? e.message : String(e)}`);
      } finally {
        enCurso.delete(idUnidad);
      }
    })
    .subscribe((estado, err) => {
      log(`Canal Realtime: ${estado}${err ? ` (${err.message})` : ''}`);
    });

  const salir = async () => {
    log('Cerrando worker…');
    await db.removeChannel(canal);
    process.exit(0);
  };
  process.on('SIGINT', salir);
  process.on('SIGTERM', salir);
  log(`Worker ETA iniciado. Proveedor: ${cfg.proveedor}.`);
}

main().catch((e) => {
  console.error(`No se pudo iniciar el worker: ${e instanceof Error ? e.message : String(e)}`);
  process.exit(1);
});
