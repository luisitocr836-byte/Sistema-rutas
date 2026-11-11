-- =====================================================================
-- MoviQro · Migración 004 · Vistas para el cliente y publicación Realtime
-- =====================================================================
set search_path = public, extensions;

-- PostgREST devuelve las columnas geometry como WKB hexadecimal; para la app se exponen
-- vistas con GeoJSON y lat/lon planos. security_invoker = true => se aplica RLS del usuario.

create or replace view public.v_rutas with (security_invoker = true) as
select r.id_ruta, r.numero_ruta, r.nombre, r.origen, r.destino, r.distancia_km, r.color_hex,
       r.horario_inicio, r.horario_fin, r.frecuencia_promedio_min, r.activa, r.fuente_datos,
       ST_AsGeoJSON(r.trazado)::jsonb as trazado_geojson,
       (select count(*) from public.paradas p where p.id_ruta = r.id_ruta)::integer as total_paradas
  from public.rutas r;

create or replace view public.v_paradas with (security_invoker = true) as
select p.id_parada, p.id_ruta, p.nombre, p.referencia_vial, p.orden_secuencia, p.es_nodo_transferencia,
       p.fuente_datos,
       ST_Y(p.ubicacion) as latitud,
       ST_X(p.ubicacion) as longitud
  from public.paradas p;

create or replace view public.v_incidencias with (security_invoker = true) as
select i.id_incidencia, i.id_ruta_afectada, i.tipo_incidencia, i.descripcion, i.retraso_estimado_min,
       i.activa, i.fecha_reporte, i.fuente_datos,
       case when i.ubicacion_incidencia is null then null else ST_Y(i.ubicacion_incidencia) end as latitud,
       case when i.ubicacion_incidencia is null then null else ST_X(i.ubicacion_incidencia) end as longitud
  from public.incidencias_viales i;

-- Resumen de validación por ruta (solo observaciones reales con tiempo observado).
create or replace view public.v_mae_por_ruta with (security_invoker = true) as
select u.id_ruta,
       count(*)                           as n,
       round(avg(e.error_absoluto_min), 3) as mae_min,
       round(avg(e.error_porcentual), 3)   as mape_pct,
       max(e.error_absoluto_min)           as max_error_min
  from public.estimaciones_eta e
  join public.unidades u on u.id_unidad = e.id_unidad
 where e.tiempo_real_min is not null and not e.es_simulado
 group by u.id_ruta;

-- ---------------------------------------------------------------------
-- Supabase Realtime: publicar cambios de unidades (posición), estimaciones y telemetría.
-- Se protege con RLS: Realtime solo entrega filas que el rol puede leer.
-- Si la publicación no existe (PostgreSQL fuera de Supabase) se omite sin error.
-- ---------------------------------------------------------------------
do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['unidades', 'estimaciones_eta', 'coordenadas_log'] loop
      if not exists (
        select 1 from pg_publication_tables
         where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
      ) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  else
    raise notice 'Publicación supabase_realtime no encontrada: se omite la configuración de Realtime.';
  end if;
end;
$$;
