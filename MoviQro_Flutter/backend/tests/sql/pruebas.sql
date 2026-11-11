\set ON_ERROR_STOP on
\echo '== Pruebas SQL de MoviQro =='
set search_path = public, extensions;

-- 1. Semillas, SRID e índices GiST
do $$
declare n int;
begin
  select count(*) into n from public.rutas;           if n <> 2  then raise exception 'FALLO: se esperaban 2 rutas, hay %', n; end if;
  select count(*) into n from public.paradas;         if n <> 10 then raise exception 'FALLO: se esperaban 10 paradas, hay %', n; end if;
  select count(*) into n from public.rutas where ST_SRID(trazado) <> 4326; if n <> 0 then raise exception 'FALLO: SRID distinto de 4326'; end if;
  select count(*) into n from pg_indexes where schemaname='public' and indexdef ilike '%using gist%';
  if n < 5 then raise exception 'FALLO: se esperaban >=5 índices GiST, hay %', n; end if;
  select count(*) into n from public.rutas where distancia_km is null or distancia_km <= 0; if n <> 0 then raise exception 'FALLO: distancia_km no calculada'; end if;
  raise notice 'OK 1: semillas, SRID 4326 e índices GiST';
end $$;

-- 2. Telemetría: trigger calcula geometría, latencia y actualiza la unidad
do $$
declare v_u int; v_geom geometry; v_lat int; v_ult double precision;
begin
  select id_unidad into v_u from public.unidades where numero_economico = 'DEMO-R38-01';
  insert into public.coordenadas_log (id_unidad, latitud, longitud, velocidad_kmh, precision_gps_m, fecha_hora, origen_dato)
  values (v_u, 20.3851, -99.9820, 25, 6, now() - interval '1 second', 'simulado');
  select punto_geom, latencia_transmision_ms into v_geom, v_lat from public.coordenadas_log where id_unidad = v_u order by id_log desc limit 1;
  if v_geom is null or ST_X(v_geom) <> -99.9820 or ST_Y(v_geom) <> 20.3851 then raise exception 'FALLO: punto_geom incorrecto (orden lon/lat)'; end if;
  if v_lat is null or v_lat < 0 then raise exception 'FALLO: latencia no calculada'; end if;
  select ultima_latitud into v_ult from public.unidades where id_unidad = v_u;
  if v_ult <> 20.3851 then raise exception 'FALLO: unidades.ultima_latitud no se actualizó'; end if;
  -- un registro MÁS ANTIGUO no debe pisar la última posición
  insert into public.coordenadas_log (id_unidad, latitud, longitud, fecha_hora) values (v_u, 20.3889, -99.9961, now() - interval '5 minutes');
  select ultima_latitud into v_ult from public.unidades where id_unidad = v_u;
  if v_ult <> 20.3851 then raise exception 'FALLO: un registro antiguo sobrescribió la posición'; end if;
  raise notice 'OK 2: triggers de telemetría (geometría, latencia, última posición)';
end $$;

-- 3. Siguiente parada (entre parada 2 y 3 debe ser la 3)
do $$
declare v_u int; v_orden int; v_dist double precision;
begin
  select id_unidad into v_u from public.unidades where numero_economico = 'DEMO-R38-01';
  select orden_secuencia, distancia_por_ruta_m into v_orden, v_dist from public.fn_siguiente_parada(v_u);
  if v_orden <> 3 then raise exception 'FALLO: siguiente parada esperada 3, obtenida %', v_orden; end if;
  if v_dist <= 0 or v_dist > 5000 then raise exception 'FALLO: distancia por ruta inverosímil: %', v_dist; end if;
  raise notice 'OK 3: fn_siguiente_parada -> parada % a % m por ruta', v_orden, round(v_dist::numeric);
end $$;

-- 4. Validaciones (CHECK y trigger)
do $$
declare v_u int;
begin
  select id_unidad into v_u from public.unidades where numero_economico = 'DEMO-R38-01';
  begin insert into public.coordenadas_log (id_unidad, latitud, longitud, fecha_hora) values (v_u, 91, -99.9, now());
        raise exception 'FALLO: aceptó latitud 91';
  exception when check_violation then null; end;
  begin insert into public.coordenadas_log (id_unidad, latitud, longitud, fecha_hora) values (v_u, 0, 0, now());
        raise exception 'FALLO: aceptó (0,0)';
  exception when check_violation then null; end;
  begin insert into public.coordenadas_log (id_unidad, latitud, longitud, fecha_hora) values (v_u, 20.38, -99.98, now() + interval '1 hour');
        raise exception 'FALLO: aceptó fecha futura';
  exception when sqlstate '22023' then null; end;
  raise notice 'OK 4: restricciones de integridad';
end $$;

-- 5. RLS: lectura pública y escritura restringida
do $$
declare v_u int; v_uid uuid := gen_random_uuid(); v_otro uuid := gen_random_uuid(); n int;
begin
  select id_unidad into v_u from public.unidades where numero_economico = 'DEMO-R38-01';
  insert into auth.users(id) values (v_uid), (v_otro);
  insert into public.autorizaciones_transmision (id_unidad, auth_user_id) values (v_u, v_uid);

  set local role anon;
  select count(*) into n from public.rutas;  if n <> 2 then raise exception 'FALLO: anon no ve las rutas (%)', n; end if;
  select count(*) into n from public.v_rutas; if n <> 2 then raise exception 'FALLO: anon no ve v_rutas (%)', n; end if;
  begin insert into public.coordenadas_log (id_unidad, latitud, longitud, fecha_hora) values (v_u, 20.38, -99.98, now());
        raise exception 'FALLO: anon pudo insertar telemetría';
  exception when insufficient_privilege then null; end;
  begin update public.unidades set estado_operativo = 'inactiva';
        raise exception 'FALLO: anon pudo actualizar unidades';
  exception when insufficient_privilege then null; end;
  begin perform public.fn_registrar_llegada(v_u, 1, now());
        raise exception 'FALLO: anon pudo ejecutar fn_registrar_llegada';
  exception when insufficient_privilege then null; end;
  reset role;

  -- authenticated SIN autorización
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_otro::text, true);
  begin insert into public.coordenadas_log (id_unidad, latitud, longitud, fecha_hora, origen_dato) values (v_u, 20.38, -99.98, now(), 'real');
        raise exception 'FALLO: usuario no autorizado pudo insertar';
  exception when insufficient_privilege then null; end;
  reset role;

  -- authenticated AUTORIZADO
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', v_uid::text, true);
  insert into public.coordenadas_log (id_unidad, latitud, longitud, velocidad_kmh, fecha_hora, origen_dato) values (v_u, 20.3840, -99.9775, 20, now(), 'real');
  begin insert into public.coordenadas_log (id_unidad, latitud, longitud, fecha_hora, origen_dato) values (v_u, 20.38, -99.98, now(), 'simulado');
        raise exception 'FALLO: usuario autorizado insertó origen simulado';
  exception when insufficient_privilege then null; end;
  reset role;
  raise notice 'OK 5: RLS (lectura pública; inserción solo autorizada y origen real)';
end $$;

-- 6. Llegada, error absoluto generado y MAE (excluye simulados y pendientes)
do $$
declare v_u int; v_p int; n int; res record; v_ea numeric;
begin
  select id_unidad into v_u from public.unidades where numero_economico = 'DEMO-R38-01';
  select p.id_parada into v_p from public.paradas p join public.rutas r using (id_ruta) where r.numero_ruta='38' and p.orden_secuencia = 3;

  insert into public.estimaciones_eta (id_unidad, id_parada_objetivo, distancia_restante_m, fuente_calculo, eta_estimado_min, fecha_calculo, es_simulado)
  values (v_u, v_p, 500, 'respaldo_ruta', 2.00, now() - interval '3 minutes', false),   -- real, error esperado 1.00
         (v_u, v_p, 500, 'respaldo_ruta', 9.00, now() - interval '3 minutes', true);    -- simulada (excluida del MAE)
  select public.fn_registrar_llegada(v_u, v_p, now()) into n;
  if n <> 2 then raise exception 'FALLO: se esperaban 2 estimaciones actualizadas, %', n; end if;

  select error_absoluto_min into v_ea from public.estimaciones_eta where eta_estimado_min = 2.00 and id_unidad = v_u;
  if v_ea is null or abs(v_ea - 1.00) > 0.02 then raise exception 'FALLO: error absoluto esperado ~1.00, obtenido %', v_ea; end if;

  -- una estimación sin tiempo real no debe contar
  insert into public.estimaciones_eta (id_unidad, id_parada_objetivo, distancia_restante_m, fuente_calculo, eta_estimado_min)
  values (v_u, v_p, 100, 'osrm', 1.0);

  select * into res from public.fn_mae(null, null, false);
  if res.n <> 1 then raise exception 'FALLO: MAE debe usar 1 observación válida real, usó %', res.n; end if;
  if abs(res.mae_min - 1.00) > 0.02 then raise exception 'FALLO: MAE esperado ~1.00, obtenido %', res.mae_min; end if;
  select * into res from public.fn_mae(null, null, true);
  if res.n <> 2 then raise exception 'FALLO: con simulados debe haber 2 observaciones, hay %', res.n; end if;
  raise notice 'OK 6: fn_registrar_llegada, error absoluto generado y fn_mae';
end $$;

-- 7. Rutas cercanas
do $$
declare n int;
begin
  select count(*) into n from public.fn_rutas_cercanas(20.3851, -99.9820, 300);
  if n < 1 then raise exception 'FALLO: fn_rutas_cercanas no encontró rutas junto al trazado'; end if;
  select count(*) into n from public.fn_rutas_cercanas(19.4326, -99.1332, 300);
  if n <> 0 then raise exception 'FALLO: no debe haber rutas en CDMX'; end if;
  raise notice 'OK 7: fn_rutas_cercanas';
end $$;

\echo '== TODAS LAS PRUEBAS SQL PASARON =='
