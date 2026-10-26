-- aqui ya viene la correccion de las bases pasadas

-- ============================================================================
-- 0. CORREGIR LA RESTRICCIÓN CHECK Y LIMPIAR IDs PARA EVITAR DUPLICADOS
-- ============================================================================
ALTER TABLE estimaciones_eta 
DROP CONSTRAINT IF EXISTS estimaciones_eta_fuente_calculo_check;

ALTER TABLE estimaciones_eta 
ADD CONSTRAINT estimaciones_eta_fuente_calculo_check 
CHECK (fuente_calculo IN ('PostGIS_Base', 'PostGIS_OSRM', 'Google_Distance_Matrix', 'OSRM', 'Hibrido_Suavizado'));

TRUNCATE TABLE rutas, paradas, unidades, coordenadas_log, incidencias_viales, estimaciones_eta 
RESTART IDENTITY CASCADE;

-- ============================================================================
-- 1. INSERTAR LAS 2 RUTAS PILOTO (38 y 39)
-- ============================================================================
INSERT INTO rutas (id_ruta, numero_ruta, nombre, origen, destino, distancia_km, color_hex, frecuencia_promedio_min, trazado)
VALUES 
(
    38, 
    'Ruta 38', 
    'Panamericana - ITSJR - Río Moctezuma - Los Patos', 
    'Miguel Hidalgo / Panamericana', 
    'Los Patos / Av. Universidad', 
    11.10, 
    '#D81B60', 
    15,
    ST_SetSRID(ST_GeomFromGeoJSON('{
        "type": "LineString",
        "coordinates": [
            [-100.001732, 20.375967],
            [-99.995130, 20.377745],
            [-99.986373, 20.375518],
            [-99.981977, 20.375308],
            [-99.976207, 20.373093],
            [-99.969425, 20.379351],
            [-99.966849, 20.386669],
            [-99.957139, 20.386022],
            [-99.956982, 20.399220],
            [-99.959006, 20.400134]
        ]
    }'), 4326)
),
(
    39, 
    'Ruta 39', 
    'Panamericana - ITSJR - Lomas del Pedregoso - Av. México', 
    'Miguel Hidalgo / Panamericana', 
    'Lomas del Pedregoso / Av. México', 
    7.28, 
    '#1E88E5', 
    15,
    ST_SetSRID(ST_GeomFromGeoJSON('{
        "type": "LineString",
        "coordinates": [
            [-100.001713, 20.375881],
            [-99.995130, 20.377745],
            [-99.986373, 20.375518],
            [-99.981830, 20.375288],
            [-99.976207, 20.373093],
            [-99.969486, 20.379377],
            [-99.967587, 20.378834],
            [-99.957423, 20.377685],
            [-99.951925, 20.375453],
            [-99.944453, 20.374200]
        ]
    }'), 4326)
);

-- ============================================================================
-- 2. INSERTAR 5 PARADAS DE PRUEBA (INCLUYENDO AFUERA DEL TEC)
-- ============================================================================
INSERT INTO paradas (id_ruta, nombre, referencia_vial, orden_secuencia, es_nodo_transferencia, ubicacion)
VALUES
    (38, 'Base Panamericana / Miguel Hidalgo', 'Av. Panamericana Poniente', 1, FALSE, ST_SetSRID(ST_MakePoint(-100.001732, 20.375967), 4326)),
    (38, 'Cruce Paseo Central', 'Paseo Central esq. Av. Tecnológico', 2, TRUE, ST_SetSRID(ST_MakePoint(-99.986373, 20.375518), 4326)),
    (38, 'Instituto Tecnológico (ITSJR)', 'Av. Tecnológico #2 frente al acceso principal', 3, TRUE, ST_SetSRID(ST_MakePoint(-99.981977, 20.375308), 4326)),
    (38, 'Río Moctezuma / Claveles', 'Av. Río Moctezuma zona oriente', 4, FALSE, ST_SetSRID(ST_MakePoint(-99.957139, 20.386022), 4326)),
    (39, 'Instituto Tecnológico (ITSJR)', 'Av. Tecnológico #2 frente al acceso principal', 1, TRUE, ST_SetSRID(ST_MakePoint(-99.981830, 20.375288), 4326));

-- ============================================================================
-- 3. INSERTAR 2 UNIDADES DE TRANSPORTE DE PRUEBA
-- ============================================================================
INSERT INTO unidades (id_ruta, numero_economico, placa, dispositivo_id, estado_operativo)
VALUES
    (38, 'R38-UNIDAD-01', 'QRO-3801-A', 'ANDROID-GPS-01', 'en_ruta'),
    (39, 'R39-UNIDAD-02', 'QRO-3902-B', 'ANDROID-GPS-02', 'en_ruta');

-- ============================================================================
-- 4. INSERTAR 5 REGISTROS DE TELEMETRÍA GPS (coordenadas_log)
-- ============================================================================
INSERT INTO coordenadas_log (id_unidad, id_ruta, latitud, longitud, altitud_m, velocidad_kmh, precision_gps_m, punto_geom, latencia_transmision_ms)
VALUES
    (1, 38, 20.376462, -99.988783, 1966.0, 28.5, 4.2, ST_SetSRID(ST_MakePoint(-99.988783, 20.376462), 4326), 180),
    (1, 38, 20.375518, -99.986373, 1970.0, 22.0, 3.8, ST_SetSRID(ST_MakePoint(-99.986373, 20.375518), 4326), 210),
    (1, 38, 20.375684, -99.984732, 1970.5, 25.4, 3.5, ST_SetSRID(ST_MakePoint(-99.984732, 20.375684), 4326), 165),
    (2, 39, 20.376968, -99.990853, 1960.0, 31.0, 4.5, ST_SetSRID(ST_MakePoint(-99.990853, 20.376968), 4326), 195),
    (2, 39, 20.375539, -99.983518, 1972.7, 26.8, 3.9, ST_SetSRID(ST_MakePoint(-99.983518, 20.375539), 4326), 172);

-- ============================================================================
-- 5. INSERTAR 2 INCIDENCIAS VIALES DE PRUEBA
-- ============================================================================
INSERT INTO incidencias_viales (id_ruta_afectada, tipo_incidencia, descripcion, retraso_estimado_min, ubicacion_incidencia)
VALUES
    (38, 'congestion_carretera_57', 'Tráfico lento en cruce de Paseo Central por desvío de Carretera 57', 5, ST_SetSRID(ST_MakePoint(-99.986373, 20.375518), 4326)),
    (39, 'obra_publica', 'Reducción de carril por bacheo sobre Av. Tecnológico', 3, ST_SetSRID(ST_MakePoint(-99.983518, 20.375539), 4326));

-- ============================================================================
-- 6. INSERTAR 3 ESTIMACIONES DE ETA
-- ============================================================================
INSERT INTO estimaciones_eta (id_unidad, id_parada_objetivo, distancia_restante_m, velocidad_suavizada_kmh, condicion_trafico, fuente_calculo, eta_estimado_min, tiempo_real_min, latencia_respuesta_ms)
VALUES
    (1, 3, 290.15, 25.4, 'fluido', 'PostGIS_OSRM', 1.20, 1.35, 320),
    (1, 4, 3150.40, 22.0, 'moderado', 'Google_Distance_Matrix', 9.50, 10.80, 450),
    (2, 5, 178.60, 26.8, 'fluido', 'PostGIS_OSRM', 0.85, 0.90, 290);

-- ============================================================================
-- 7. CONSULTA DE VERIFICACIÓN PRELIMINAR (PARA TU CAPTURA DE PANTALLA)
-- ============================================================================
SELECT 
    u.numero_economico AS unidad,
    r.numero_ruta AS ruta,
    p.nombre AS parada_destino,
    ROUND(ST_DistanceSphere(u.ultima_posicion, p.ubicacion)::numeric, 2) AS distancia_actual_m,
    e.eta_estimado_min,
    e.tiempo_real_min,
    e.error_absoluto_min,
    e.error_porcentual,
    e.latencia_respuesta_ms
FROM estimaciones_eta e
JOIN unidades u ON e.id_unidad = u.id_unidad
JOIN rutas r ON u.id_ruta = r.id_ruta
JOIN paradas p ON e.id_parada_objetivo = p.id_parada;