-- =====================================================================
-- MoviQro · Migración 002 · Índices (incluye índices espaciales GiST)
-- =====================================================================
set search_path = public, extensions;

-- Espaciales (GiST)
create index if not exists idx_rutas_trazado_gist        on public.rutas             using gist (trazado);
create index if not exists idx_paradas_ubicacion_gist    on public.paradas           using gist (ubicacion);
create index if not exists idx_unidades_posicion_gist    on public.unidades          using gist (ultima_posicion);
create index if not exists idx_coordenadas_punto_gist    on public.coordenadas_log   using gist (punto_geom);
create index if not exists idx_incidencias_ubic_gist     on public.incidencias_viales using gist (ubicacion_incidencia);

-- Búsquedas frecuentes
create index if not exists idx_paradas_ruta_orden        on public.paradas (id_ruta, orden_secuencia);
create index if not exists idx_unidades_ruta             on public.unidades (id_ruta);
create index if not exists idx_coordenadas_unidad_fecha  on public.coordenadas_log (id_unidad, fecha_hora desc);
create index if not exists idx_estimaciones_unidad_fecha on public.estimaciones_eta (id_unidad, fecha_calculo desc);
create index if not exists idx_estimaciones_pendientes   on public.estimaciones_eta (id_unidad, id_parada_objetivo)
  where tiempo_real_min is null;
create index if not exists idx_estimaciones_validas      on public.estimaciones_eta (id_unidad)
  where tiempo_real_min is not null and es_simulado = false;
create index if not exists idx_incidencias_activas       on public.incidencias_viales (id_ruta_afectada)
  where activa;
