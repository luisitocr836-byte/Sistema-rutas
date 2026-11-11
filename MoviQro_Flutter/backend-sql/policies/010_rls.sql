-- =====================================================================
-- MoviQro · Políticas de seguridad (RLS) y permisos
--
-- Modelo (Avance 1, punto 5): lectura pública desde la app cliente; inserción de telemetría
-- restringida a dispositivos autenticados Y autorizados para esa unidad.
--   · Cliente (anon/authenticated): solo SELECT de catálogos y resultados.
--   · Transmisor (authenticated con fila en autorizaciones_transmision): INSERT en coordenadas_log.
--   · Worker ETA / simulador (service_role, clave solo en servidor): escribe estimaciones, etc.
--     service_role omite RLS por diseño de Supabase; su clave NUNCA debe ir en la app.
-- =====================================================================
set search_path = public, extensions;

alter table public.rutas                      enable row level security;
alter table public.paradas                    enable row level security;
alter table public.unidades                   enable row level security;
alter table public.coordenadas_log            enable row level security;
alter table public.estimaciones_eta           enable row level security;
alter table public.incidencias_viales         enable row level security;
alter table public.autorizaciones_transmision enable row level security;

-- Privilegios base: se quita todo escritura a roles públicos y se otorga lo mínimo.
revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;
grant  select on public.rutas, public.paradas, public.unidades, public.coordenadas_log,
                 public.estimaciones_eta, public.incidencias_viales to anon, authenticated;
grant  select on public.v_rutas, public.v_paradas, public.v_incidencias, public.v_mae_por_ruta to anon, authenticated;
grant  select on public.autorizaciones_transmision to authenticated;
grant  insert on public.coordenadas_log to authenticated;

-- ---------------------------------------------------------------------
-- Lectura pública de catálogos
-- ---------------------------------------------------------------------
drop policy if exists rutas_lectura_publica on public.rutas;
create policy rutas_lectura_publica on public.rutas
  for select to anon, authenticated using (activa);

drop policy if exists paradas_lectura_publica on public.paradas;
create policy paradas_lectura_publica on public.paradas
  for select to anon, authenticated
  using (exists (select 1 from public.rutas r where r.id_ruta = paradas.id_ruta and r.activa));

drop policy if exists unidades_lectura_publica on public.unidades;
create policy unidades_lectura_publica on public.unidades
  for select to anon, authenticated using (estado_operativo = 'activa');

drop policy if exists incidencias_lectura_publica on public.incidencias_viales;
create policy incidencias_lectura_publica on public.incidencias_viales
  for select to anon, authenticated using (activa);

drop policy if exists estimaciones_lectura_publica on public.estimaciones_eta;
create policy estimaciones_lectura_publica on public.estimaciones_eta
  for select to anon, authenticated using (true);

-- Telemetría: solo las últimas 24 h son visibles al público (el histórico queda para service_role).
drop policy if exists coordenadas_lectura_reciente on public.coordenadas_log;
create policy coordenadas_lectura_reciente on public.coordenadas_log
  for select to anon, authenticated using (fecha_hora > now() - interval '24 hours');

-- ---------------------------------------------------------------------
-- Autorización de transmisores
-- ---------------------------------------------------------------------
drop policy if exists autorizacion_propia on public.autorizaciones_transmision;
create policy autorizacion_propia on public.autorizaciones_transmision
  for select to authenticated using (auth_user_id = (select auth.uid()));

-- Inserción de telemetría: usuario autenticado, autorizado para ESA unidad, unidad activa,
-- origen 'real' (el origen 'simulado' solo lo inserta service_role) y ruta coherente.
drop policy if exists coordenadas_insertar_autorizado on public.coordenadas_log;
create policy coordenadas_insertar_autorizado on public.coordenadas_log
  for insert to authenticated
  with check (
    origen_dato = 'real'
    and exists (
      select 1
        from public.autorizaciones_transmision a
        join public.unidades u on u.id_unidad = a.id_unidad
       where a.auth_user_id = (select auth.uid())
         and a.id_unidad = coordenadas_log.id_unidad
         and u.estado_operativo = 'activa'
         and (coordenadas_log.id_ruta is null or coordenadas_log.id_ruta = u.id_ruta)
    )
  );

-- Nota: el modo "Demostración" de la app NO escribe en la base de datos; el simulador GPS
-- (carpeta simulador-gps) usa service_role desde un equipo de confianza y marca origen_dato='simulado'.

-- ---------------------------------------------------------------------
-- Funciones: solo las necesarias para clientes; fn_registrar_llegada solo service_role.
-- ---------------------------------------------------------------------
revoke execute on function public.fn_registrar_llegada(integer, integer, timestamptz) from public, anon, authenticated;
grant  execute on function public.fn_registrar_llegada(integer, integer, timestamptz) to service_role;

grant execute on function public.fn_siguiente_parada(integer) to anon, authenticated;
grant execute on function public.fn_rutas_cercanas(double precision, double precision, double precision) to anon, authenticated;
grant execute on function public.fn_mae(integer, timestamptz, boolean) to anon, authenticated;
