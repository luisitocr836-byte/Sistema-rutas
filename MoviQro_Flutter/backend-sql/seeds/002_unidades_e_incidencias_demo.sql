-- =====================================================================
-- MoviQro · Semilla 002 · Unidades e incidencia DEMOSTRATIVAS
-- ⚠ DATOS DEMOSTRATIVOS (fuente_datos = demostracion). No representan unidades ni incidencias reales.
-- Requiere haber ejecutado seeds/001_rutas_y_paradas.sql.
-- Idempotente.
-- =====================================================================
set search_path = public, extensions;

insert into public.unidades (id_ruta, numero_economico, dispositivo_id, estado_operativo, fuente_datos)
select r.id_ruta, 'DEMO-R38-01', 'DEMO-DEVICE-R38-01', 'activa', 'demostracion'
  from public.rutas r where r.numero_ruta = '38'
on conflict (numero_economico) do nothing;

insert into public.unidades (id_ruta, numero_economico, dispositivo_id, estado_operativo, fuente_datos)
select r.id_ruta, 'DEMO-R39-01', 'DEMO-DEVICE-R39-01', 'activa', 'demostracion'
  from public.rutas r where r.numero_ruta = '39'
on conflict (numero_economico) do nothing;

-- Incidencia demostrativa (para ver el flujo de incidencias en la app).
insert into public.incidencias_viales (id_ruta_afectada, tipo_incidencia, descripcion, retraso_estimado_min, ubicacion_incidencia, activa, fuente_datos)
select r.id_ruta, 'congestion',
       'DEMOSTRACIÓN: ejemplo de incidencia vial. No corresponde a un evento real.',
       5, ST_SetSRID(ST_MakePoint(-99.9895, 20.3872), 4326), true, 'demostracion'
  from public.rutas r
 where r.numero_ruta = '38'
   and not exists (select 1 from public.incidencias_viales i where i.fuente_datos = 'demostracion' and i.tipo_incidencia = 'congestion');

-- Autorizar a un chofer/dispositivo REAL para transmitir (ejecutar manualmente, con el UUID de Auth):
--   insert into public.autorizaciones_transmision (id_unidad, auth_user_id)
--   select id_unidad, '00000000-0000-0000-0000-000000000000'::uuid  -- ← reemplazar por auth.users.id
--     from public.unidades where numero_economico = 'DEMO-R38-01';
