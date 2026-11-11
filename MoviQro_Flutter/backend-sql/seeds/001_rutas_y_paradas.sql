-- =====================================================================
-- MoviQro · Semilla de rutas y paradas
-- GENERADO por backend/scripts/generar-derivados.ts a partir de datos-espaciales/*.geojson.
-- No editar a mano: edite el GeoJSON y ejecute `npm run datos:generar`.
--
-- ⚠ CONTIENE DATOS DEMOSTRATIVOS (fuente_datos = demostracion). Trazados y paradas
--   ilustrativos; NO son los recorridos oficiales. Reemplazar por los GeoJSON del Avance 1.
-- Orden de coordenadas: (longitud latitud). SRID 4326.
-- Idempotente: se puede ejecutar varias veces.
-- =====================================================================
set search_path = public, extensions;

-- ruta_38.geojson · fuente_datos=demostracion
insert into public.rutas (numero_ruta, nombre, origen, destino, color_hex, horario_inicio, horario_fin, frecuencia_promedio_min, trazado, fuente_datos)
values ('38', 'Ruta 38 (demostración)', 'Parque Hidalgo / Centro Histórico', 'Terminal ruta 38 (demostración)', '#1687ff', '06:00', '21:00', null,
        ST_GeomFromText('LINESTRING(-99.9961 20.3889, -99.993 20.3885, -99.9895 20.3872, -99.986 20.386, -99.982 20.3851, -99.9775 20.384, -99.9735 20.3826, -99.97 20.381, -99.966 20.3805, -99.962 20.3815, -99.9585 20.383)', 4326), 'demostracion')
on conflict (numero_ruta) do update set nombre = excluded.nombre, origen = excluded.origen, destino = excluded.destino,
  color_hex = excluded.color_hex, horario_inicio = excluded.horario_inicio, horario_fin = excluded.horario_fin,
  frecuencia_promedio_min = excluded.frecuencia_promedio_min, trazado = excluded.trazado, fuente_datos = excluded.fuente_datos;
update public.rutas set distancia_km = round((ST_Length(trazado::geography) / 1000.0)::numeric, 3) where numero_ruta = '38';
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Parque Hidalgo / Centro Histórico', 'Calle Miguel Hidalgo (referencia vial según Avance 1)', 1, true, ST_SetSRID(ST_MakePoint(-99.9961, 20.3889), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '38'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Av. Universidad (demostración)', 'Av. Universidad', 2, false, ST_SetSRID(ST_MakePoint(-99.986, 20.386), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '38'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Río Moctezuma / Claveles', 'Zona Río Moctezuma / Claveles', 3, false, ST_SetSRID(ST_MakePoint(-99.9775, 20.384), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '38'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Instituto Tecnológico (ITSJR)', 'Av. Tecnológico', 4, true, ST_SetSRID(ST_MakePoint(-99.966, 20.3805), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '38'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Terminal ruta 38 (demostración)', 'Punto final ilustrativo', 5, false, ST_SetSRID(ST_MakePoint(-99.9585, 20.383), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '38'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;

-- ruta_39.geojson · fuente_datos=demostracion
insert into public.rutas (numero_ruta, nombre, origen, destino, color_hex, horario_inicio, horario_fin, frecuencia_promedio_min, trazado, fuente_datos)
values ('39', 'Ruta 39 (demostración)', 'Base ruta 39 (demostración)', 'Terminal ruta 39 (demostración)', '#ed69b5', '06:00', '21:00', null,
        ST_GeomFromText('LINESTRING(-100.004 20.379, -100 20.38, -99.996 20.3812, -99.992 20.3815, -99.988 20.3808, -99.984 20.38, -99.98 20.3805, -99.976 20.3812)', 4326), 'demostracion')
on conflict (numero_ruta) do update set nombre = excluded.nombre, origen = excluded.origen, destino = excluded.destino,
  color_hex = excluded.color_hex, horario_inicio = excluded.horario_inicio, horario_fin = excluded.horario_fin,
  frecuencia_promedio_min = excluded.frecuencia_promedio_min, trazado = excluded.trazado, fuente_datos = excluded.fuente_datos;
update public.rutas set distancia_km = round((ST_Length(trazado::geography) / 1000.0)::numeric, 3) where numero_ruta = '39';
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Base ruta 39 (demostración)', 'Punto inicial ilustrativo', 1, false, ST_SetSRID(ST_MakePoint(-100.004, 20.379), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '39'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Hda. Los Arrayanes (demostración)', 'Hda. Los Arrayanes', 2, false, ST_SetSRID(ST_MakePoint(-99.996, 20.3812), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '39'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Av. Tecnológico (demostración)', 'Av. Tecnológico', 3, false, ST_SetSRID(ST_MakePoint(-99.988, 20.3808), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '39'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Instituto Tecnológico (ITSJR)', 'Av. Tecnológico', 4, true, ST_SetSRID(ST_MakePoint(-99.98, 20.3805), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '39'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;
insert into public.paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion, fuente_datos)
select r.id_ruta, 'Terminal ruta 39 (demostración)', 'Punto final ilustrativo', 5, false, ST_SetSRID(ST_MakePoint(-99.976, 20.3812), 4326), 'demostracion'
  from public.rutas r where r.numero_ruta = '39'
on conflict (id_ruta, orden_secuencia) do update set nombre = excluded.nombre, referencia_vial = excluded.referencia_vial,
  es_nodo_transferencia = excluded.es_nodo_transferencia, ubicacion = excluded.ubicacion, fuente_datos = excluded.fuente_datos;
