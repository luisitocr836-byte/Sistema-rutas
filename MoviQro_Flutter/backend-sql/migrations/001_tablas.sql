-- =====================================================================
-- MoviQro · Migración 001 · Extensiones y tablas
-- Esquema relacional-espacial (Avance 1 y 2): rutas, paradas, unidades,
-- coordenadas_log, estimaciones_eta, incidencias_viales (+ una tabla de apoyo
-- para autorizar dispositivos transmisores).
--
-- Convención espacial: SRID 4326 (WGS84). Orden de coordenadas: (longitud, latitud),
-- es decir ST_SetSRID(ST_MakePoint(longitud, latitud), 4326).
--
-- Ejecutar en el SQL Editor de Supabase (o con psql) en el orden:
--   migrations/001 → 002 → 003 → 004 → policies/010 → seeds/*
-- Es reproducible: usa IF NOT EXISTS donde es posible.
-- =====================================================================

create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

-- Para que los tipos geometry resuelvan en esta sesión (en Supabase ya es el valor por defecto).
set search_path = public, extensions;

-- ---------------------------------------------------------------------
-- rutas
-- ---------------------------------------------------------------------
create table if not exists public.rutas (
  id_ruta                 integer generated always as identity primary key,
  numero_ruta             varchar(10)  not null unique,
  nombre                  varchar(120) not null,
  origen                  varchar(120) not null,
  destino                 varchar(120) not null,
  distancia_km            numeric(8,3) check (distancia_km is null or distancia_km >= 0),
  color_hex               varchar(7)   check (color_hex is null or color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  horario_inicio          time,
  horario_fin             time,
  frecuencia_promedio_min integer      check (frecuencia_promedio_min is null or frecuencia_promedio_min > 0),
  activa                  boolean      not null default true,
  trazado                 geometry(LineString, 4326) not null,
  -- Procedencia del dato: evita presentar datos demostrativos como oficiales.
  fuente_datos            text         not null default 'demostracion'
                          check (fuente_datos in ('oficial', 'levantamiento_equipo', 'demostracion')),
  creado_en               timestamptz  not null default now(),
  actualizado_en          timestamptz  not null default now()
);

-- ---------------------------------------------------------------------
-- paradas
-- ---------------------------------------------------------------------
create table if not exists public.paradas (
  id_parada             integer generated always as identity primary key,
  id_ruta               integer      not null references public.rutas(id_ruta) on delete cascade,
  nombre                varchar(150) not null,
  referencia_vial       varchar(200),
  orden_secuencia       integer      not null check (orden_secuencia > 0),
  es_nodo_transferencia boolean      not null default false,
  ubicacion             geometry(Point, 4326) not null,
  fuente_datos          text         not null default 'demostracion'
                        check (fuente_datos in ('oficial', 'levantamiento_equipo', 'demostracion')),
  creado_en             timestamptz  not null default now(),
  constraint paradas_orden_unico unique (id_ruta, orden_secuencia)
);

-- ---------------------------------------------------------------------
-- unidades
-- ---------------------------------------------------------------------
create table if not exists public.unidades (
  id_unidad            integer generated always as identity primary key,
  id_ruta              integer references public.rutas(id_ruta) on delete set null,
  numero_economico     varchar(30) not null unique,
  placa                varchar(15),
  -- Identificador opaco del dispositivo transmisor (no es un secreto).
  dispositivo_id       varchar(80) unique,
  estado_operativo     text not null default 'activa'
                       check (estado_operativo in ('activa', 'inactiva', 'mantenimiento')),
  ultima_latitud       double precision check (ultima_latitud  is null or ultima_latitud  between -90  and 90),
  ultima_longitud      double precision check (ultima_longitud is null or ultima_longitud between -180 and 180),
  ultima_velocidad_kmh double precision check (ultima_velocidad_kmh is null or ultima_velocidad_kmh >= 0),
  ultima_posicion      geometry(Point, 4326),
  ultima_actualizacion timestamptz,
  ultimo_origen_dato   text check (ultimo_origen_dato is null or ultimo_origen_dato in ('real', 'simulado')),
  fuente_datos         text not null default 'demostracion'
                       check (fuente_datos in ('oficial', 'levantamiento_equipo', 'demostracion')),
  creado_en            timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- autorizaciones_transmision (tabla de apoyo)
-- Vincula un usuario de Supabase Auth (el teléfono/chofer) con UNA unidad.
-- Solo una unidad autorizada puede insertar en coordenadas_log (ver RLS).
-- ---------------------------------------------------------------------
create table if not exists public.autorizaciones_transmision (
  id_unidad    integer primary key references public.unidades(id_unidad) on delete cascade,
  auth_user_id uuid    not null unique references auth.users(id) on delete cascade,
  creado_en    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- coordenadas_log (telemetría)
-- ---------------------------------------------------------------------
create table if not exists public.coordenadas_log (
  id_log                  bigint generated always as identity primary key,
  id_unidad               integer not null references public.unidades(id_unidad) on delete cascade,
  id_ruta                 integer references public.rutas(id_ruta) on delete set null,
  latitud                 double precision not null check (latitud  between -90  and 90),
  longitud                double precision not null check (longitud between -180 and 180),
  altitud_m               double precision,
  velocidad_kmh           double precision check (velocidad_kmh is null or (velocidad_kmh >= 0 and velocidad_kmh <= 200)),
  precision_gps_m         double precision check (precision_gps_m is null or precision_gps_m >= 0),
  punto_geom              geometry(Point, 4326),            -- lo calcula el trigger a partir de lat/lon
  -- Retraso entre la captura (fecha_hora, reloj del dispositivo) y la recepción en la base de datos.
  -- Lo calcula el trigger; depende de la sincronía de relojes. Ver documentacion/.
  latencia_transmision_ms integer check (latencia_transmision_ms is null or latencia_transmision_ms >= 0),
  fecha_hora              timestamptz not null,
  recibido_en             timestamptz not null default now(),
  -- Diferencia datos reales de simulados.
  origen_dato             text not null default 'real' check (origen_dato in ('real', 'simulado')),
  constraint coordenadas_no_cero check (not (latitud = 0 and longitud = 0))
);

-- ---------------------------------------------------------------------
-- estimaciones_eta
-- ---------------------------------------------------------------------
create table if not exists public.estimaciones_eta (
  id_estimacion           bigint generated always as identity primary key,
  id_unidad               integer not null references public.unidades(id_unidad) on delete cascade,
  id_parada_objetivo      integer not null references public.paradas(id_parada) on delete cascade,
  distancia_restante_m    numeric(10,2) not null check (distancia_restante_m >= 0),
  velocidad_suavizada_kmh numeric(6,2)  check (velocidad_suavizada_kmh is null or velocidad_suavizada_kmh >= 0),
  condicion_trafico       text not null default 'desconocido'
                          check (condicion_trafico in ('fluido', 'moderado', 'denso', 'desconocido')),
  fuente_calculo          text not null
                          check (fuente_calculo in ('osrm', 'google_distance_matrix', 'respaldo_ruta')),
  eta_estimado_min        numeric(8,2) not null check (eta_estimado_min >= 0),
  -- Se llena cuando la unidad llega realmente a la parada (fn_registrar_llegada).
  tiempo_real_min         numeric(8,2) check (tiempo_real_min is null or tiempo_real_min > 0),
  fecha_llegada           timestamptz,
  error_absoluto_min      numeric(8,2) generated always as (
                            case when tiempo_real_min is not null
                                 then abs(eta_estimado_min - tiempo_real_min) end) stored,
  error_porcentual        numeric(8,2) generated always as (
                            case when tiempo_real_min is not null
                                 then abs(eta_estimado_min - tiempo_real_min) / tiempo_real_min * 100 end) stored,
  latencia_respuesta_ms   integer check (latencia_respuesta_ms is null or latencia_respuesta_ms >= 0),
  fecha_calculo           timestamptz not null default now(),
  -- true si la posición de origen fue simulada ("Demostración"); se excluye del MAE por defecto.
  es_simulado             boolean not null default false
);

-- ---------------------------------------------------------------------
-- incidencias_viales
-- ---------------------------------------------------------------------
create table if not exists public.incidencias_viales (
  id_incidencia        integer generated always as identity primary key,
  id_ruta_afectada     integer references public.rutas(id_ruta) on delete set null,
  tipo_incidencia      text not null check (tipo_incidencia in ('obra', 'accidente', 'bloqueo', 'congestion', 'otro')),
  descripcion          text not null check (length(btrim(descripcion)) > 0),
  retraso_estimado_min integer check (retraso_estimado_min is null or retraso_estimado_min >= 0),
  ubicacion_incidencia geometry(Point, 4326),
  activa               boolean not null default true,
  fecha_reporte        timestamptz not null default now(),
  fuente_datos         text not null default 'demostracion'
                       check (fuente_datos in ('oficial', 'levantamiento_equipo', 'demostracion'))
);

comment on table public.rutas             is 'Rutas de transporte urbano con trazado LineString (SRID 4326).';
comment on table public.paradas           is 'Paradas georreferenciadas (Point, SRID 4326) ordenadas por orden_secuencia.';
comment on table public.unidades          is 'Unidades de transporte y su última posición conocida.';
comment on table public.coordenadas_log   is 'Telemetría GPS de las unidades (histórico).';
comment on table public.estimaciones_eta  is 'Estimaciones ETA registradas para validación posterior (MAE).';
comment on table public.incidencias_viales is 'Incidencias viales que pueden afectar rutas.';
comment on table public.autorizaciones_transmision is 'Usuario de Supabase Auth autorizado a transmitir para una unidad.';
