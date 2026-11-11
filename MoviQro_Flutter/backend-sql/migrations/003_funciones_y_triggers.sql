-- =====================================================================
-- MoviQro · Migración 003 · Funciones espaciales y triggers
-- =====================================================================
set search_path = public, extensions;

-- ---------------------------------------------------------------------
-- actualizado_en de rutas
-- ---------------------------------------------------------------------
create or replace function public.fn_tocar_actualizado_en()
returns trigger language plpgsql
set search_path = public, extensions
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

drop trigger if exists trg_rutas_actualizado on public.rutas;
create trigger trg_rutas_actualizado before update on public.rutas
  for each row execute function public.fn_tocar_actualizado_en();

-- ---------------------------------------------------------------------
-- coordenadas_log: validación y cálculo de geometría antes de insertar
-- ---------------------------------------------------------------------
create or replace function public.fn_coordenadas_antes_insertar()
returns trigger language plpgsql
set search_path = public, extensions
as $$
declare
  v_ruta integer;
begin
  -- No se aceptan marcas de tiempo en el futuro (tolerancia 5 min por desfase de reloj).
  if new.fecha_hora > now() + interval '5 minutes' then
    raise exception 'fecha_hora en el futuro (%).', new.fecha_hora using errcode = '22023';
  end if;

  -- Orden PostGIS: (longitud, latitud).
  new.punto_geom := ST_SetSRID(ST_MakePoint(new.longitud, new.latitud), 4326);

  -- Si no se envió la ruta, se toma la asignada a la unidad.
  if new.id_ruta is null then
    select u.id_ruta into v_ruta from public.unidades u where u.id_unidad = new.id_unidad;
    new.id_ruta := v_ruta;
  end if;

  new.recibido_en := now();
  new.latencia_transmision_ms :=
    greatest(0, (extract(epoch from (new.recibido_en - new.fecha_hora)) * 1000)::integer);

  return new;
end;
$$;

drop trigger if exists trg_coordenadas_antes on public.coordenadas_log;
create trigger trg_coordenadas_antes before insert on public.coordenadas_log
  for each row execute function public.fn_coordenadas_antes_insertar();

-- ---------------------------------------------------------------------
-- coordenadas_log → unidades.ultima_* (solo si el registro es más reciente)
-- security definer: el transmisor no tiene permiso de UPDATE sobre unidades.
-- ---------------------------------------------------------------------
create or replace function public.fn_coordenadas_despues_insertar()
returns trigger language plpgsql security definer
set search_path = public, extensions
as $$
begin
  update public.unidades u
     set ultima_latitud       = new.latitud,
         ultima_longitud      = new.longitud,
         ultima_velocidad_kmh = new.velocidad_kmh,
         ultima_posicion      = new.punto_geom,
         ultima_actualizacion = new.fecha_hora,
         ultimo_origen_dato   = new.origen_dato
   where u.id_unidad = new.id_unidad
     and (u.ultima_actualizacion is null or u.ultima_actualizacion <= new.fecha_hora);
  return new;
end;
$$;

drop trigger if exists trg_coordenadas_despues on public.coordenadas_log;
create trigger trg_coordenadas_despues after insert on public.coordenadas_log
  for each row execute function public.fn_coordenadas_despues_insertar();

-- ---------------------------------------------------------------------
-- fn_siguiente_parada: siguiente parada relevante de una unidad.
-- Proyecta la unidad y las paradas sobre el trazado (ST_LineLocatePoint) y devuelve la primera
-- parada, por orden_secuencia, que aún no se ha rebasado (tolerancia 25 m).
-- NOTA: ST_LineLocatePoint trabaja con la fracción planar del trazado; la distancia por ruta se
-- obtiene multiplicando por la longitud geodésica. La versión TypeScript (core/siguienteParada.ts)
-- calcula en metros y puede diferir en centímetros/metros; ambas son aproximaciones urbanas.
-- ---------------------------------------------------------------------
create or replace function public.fn_siguiente_parada(p_id_unidad integer)
returns table (
  id_parada integer,
  nombre varchar,
  orden_secuencia integer,
  distancia_por_ruta_m double precision,
  distancia_lineal_m double precision
)
language sql stable
set search_path = public, extensions
as $$
  with u as (
    select un.id_unidad, un.id_ruta, un.ultima_posicion as pos
      from public.unidades un
     where un.id_unidad = p_id_unidad
       and un.id_ruta is not null
       and un.ultima_posicion is not null
  ),
  r as (
    select ru.id_ruta, ru.trazado, ST_Length(ru.trazado::geography) as largo_m
      from public.rutas ru join u on u.id_ruta = ru.id_ruta
     where ST_Length(ru.trazado::geography) > 0
  ),
  base as (
    select r.largo_m, ST_LineLocatePoint(r.trazado, u.pos) as frac_unidad, u.pos, r.trazado, r.id_ruta
      from r join u on u.id_ruta = r.id_ruta
  )
  select p.id_parada,
         p.nombre,
         p.orden_secuencia,
         greatest(0, (ST_LineLocatePoint(b.trazado, p.ubicacion) - b.frac_unidad) * b.largo_m) as distancia_por_ruta_m,
         ST_DistanceSphere(b.pos, p.ubicacion) as distancia_lineal_m
    from base b
    join public.paradas p on p.id_ruta = b.id_ruta
   where ST_LineLocatePoint(b.trazado, p.ubicacion) >= b.frac_unidad - (25.0 / b.largo_m)
   order by p.orden_secuencia
   limit 1;
$$;

-- ---------------------------------------------------------------------
-- fn_rutas_cercanas: rutas cuyo trazado pasa a menos de p_radio_m metros del punto.
-- ---------------------------------------------------------------------
create or replace function public.fn_rutas_cercanas(p_latitud double precision, p_longitud double precision, p_radio_m double precision default 500)
returns table (id_ruta integer, numero_ruta varchar, nombre varchar, distancia_m double precision)
language sql stable
set search_path = public, extensions
as $$
  select r.id_ruta, r.numero_ruta, r.nombre,
         ST_Distance(r.trazado::geography, ST_SetSRID(ST_MakePoint(p_longitud, p_latitud), 4326)::geography) as distancia_m
    from public.rutas r
   where r.activa
     and p_latitud between -90 and 90 and p_longitud between -180 and 180
     and p_radio_m > 0 and p_radio_m <= 20000
     and ST_DWithin(r.trazado::geography, ST_SetSRID(ST_MakePoint(p_longitud, p_latitud), 4326)::geography, p_radio_m)
   order by distancia_m;
$$;

-- ---------------------------------------------------------------------
-- fn_registrar_llegada: registra el tiempo real observado para las estimaciones pendientes
-- de una unidad hacia una parada. tiempo_real = momento de llegada − fecha_calculo.
-- Solo para service_role (worker). Devuelve cuántas estimaciones actualizó.
-- ---------------------------------------------------------------------
create or replace function public.fn_registrar_llegada(p_id_unidad integer, p_id_parada integer, p_momento timestamptz default now())
returns integer
language plpgsql security definer
set search_path = public, extensions
as $$
declare
  v_filas integer;
begin
  update public.estimaciones_eta e
     set tiempo_real_min = greatest(0.01, round((extract(epoch from (p_momento - e.fecha_calculo)) / 60.0)::numeric, 2)),
         fecha_llegada   = p_momento
   where e.id_unidad = p_id_unidad
     and e.id_parada_objetivo = p_id_parada
     and e.tiempo_real_min is null
     and e.fecha_calculo <= p_momento
     and e.fecha_calculo >= p_momento - interval '2 hours';
  get diagnostics v_filas = row_count;
  return v_filas;
end;
$$;

-- ---------------------------------------------------------------------
-- fn_mae: Error Absoluto Medio con observaciones válidas (tiempo_real_min no nulo).
-- Por defecto EXCLUYE estimaciones simuladas: la validación de campo debe usar datos reales.
-- ---------------------------------------------------------------------
create or replace function public.fn_mae(p_id_ruta integer default null, p_desde timestamptz default null, p_incluir_simulados boolean default false)
returns table (n bigint, mae_min numeric, mape_pct numeric, max_error_min numeric)
language sql stable
set search_path = public, extensions
as $$
  select count(*)::bigint,
         round(avg(e.error_absoluto_min), 3),
         round(avg(e.error_porcentual), 3),
         max(e.error_absoluto_min)
    from public.estimaciones_eta e
    join public.unidades u on u.id_unidad = e.id_unidad
   where e.tiempo_real_min is not null
     and (p_incluir_simulados or not e.es_simulado)
     and (p_id_ruta is null or u.id_ruta = p_id_ruta)
     and (p_desde is null or e.fecha_calculo >= p_desde);
$$;
