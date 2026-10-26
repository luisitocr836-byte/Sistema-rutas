-- ============================================================================
-- 1. EXTENSIONES REQUERIDAS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 2. TABLAS NUCLEARES DE LA ARQUITECTURA (CAPA 2)
-- ============================================================================

-- 2.1 Tabla: rutas
-- Almacena el recorrido teórico y vectorial (LineString) de cada ruta urbana
CREATE TABLE rutas (
    id_ruta INT PRIMARY KEY,
    numero_ruta VARCHAR(20) NOT NULL UNIQUE,      -- Ej. 'Ruta 38', 'Ruta 39'
    nombre VARCHAR(150) NOT NULL,
    origen VARCHAR(100) NOT NULL,
    destino VARCHAR(100) NOT NULL,
    distancia_km NUMERIC(6,2),
    color_hex VARCHAR(7) DEFAULT '#1E88E5',       -- Para renderizado en mapa móvil
    horario_inicio TIME DEFAULT '05:30:00',
    horario_fin TIME DEFAULT '22:00:00',
    frecuencia_promedio_min INT DEFAULT 15,
    activa BOOLEAN DEFAULT TRUE,
    trazado GEOMETRY(LineString, 4326) NOT NULL,  -- Geometría lineal WGS84
    creado_en TIMESTAMPTZ DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ DEFAULT NOW()
);

-- 2.2 Tabla: paradas
-- Almacena los nodos fijos/informales de ascenso y descenso (Point) por ruta
CREATE TABLE paradas (
    id_parada SERIAL PRIMARY KEY,
    id_ruta INT NOT NULL REFERENCES rutas(id_ruta) ON DELETE CASCADE,
    nombre VARCHAR(120) NOT NULL,                 -- Ej. 'Instituto Tecnológico (ITSJR)'
    referencia_vial VARCHAR(150),                 -- Ej. 'Av. Tecnológico frente a acceso principal'
    orden_secuencia INT NOT NULL,                 -- Orden de paso dentro de la ruta (1, 2, 3...)
    es_nodo_transferencia BOOLEAN DEFAULT FALSE,  -- Ej. Cruce Paseo Central / Centro Histórico
    ubicacion GEOMETRY(Point, 4326) NOT NULL,     -- Geometría puntual WGS84
    creado_en TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (id_ruta, orden_secuencia)
);

-- 2.3 Tabla: unidades
-- Almacena las unidades colectivas/dispositivos emisores asignados a las rutas
CREATE TABLE unidades (
    id_unidad SERIAL PRIMARY KEY,
    id_ruta INT REFERENCES rutas(id_ruta) ON DELETE SET NULL,
    numero_economico VARCHAR(50) NOT NULL UNIQUE, -- Ej. 'R38-UNIDAD-01'
    placa VARCHAR(20),
    dispositivo_id VARCHAR(100),                  -- Identificador del smartphone/emisor GPS
    estado_operativo VARCHAR(30) DEFAULT 'en_ruta' 
        CHECK (estado_operativo IN ('en_ruta', 'en_base', 'fuera_de_servicio', 'desvio')),
    ultima_latitud DOUBLE PRECISION,
    ultima_longitud DOUBLE PRECISION,
    ultima_velocidad_kmh DOUBLE PRECISION DEFAULT 0.0,
    ultima_posicion GEOMETRY(Point, 4326),        -- Posición actual para lectura rápida en el mapa
    ultima_actualizacion TIMESTAMPTZ DEFAULT NOW(),
    creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- 2.4 Tabla: coordenadas_log
-- Almacena el historial continuo de telemetría GPS recibida desde las unidades (Capa 1 -> Capa 2)
CREATE TABLE coordenadas_log (
    id_log BIGSERIAL PRIMARY KEY,
    id_unidad INT NOT NULL REFERENCES unidades(id_unidad) ON DELETE CASCADE,
    id_ruta INT REFERENCES rutas(id_ruta) ON DELETE SET NULL,
    latitud DOUBLE PRECISION NOT NULL,
    longitud DOUBLE PRECISION NOT NULL,
    altitud_m DOUBLE PRECISION,
    velocidad_kmh DOUBLE PRECISION DEFAULT 0.0,   -- Para algoritmo de filtrado y suavizado
    precision_gps_m DOUBLE PRECISION,             -- Margen de precisión de la antena GNSS
    punto_geom GEOMETRY(Point, 4326) NOT NULL,    -- Coordenada espacial indexada
    latencia_transmision_ms INT,                  -- Métrica de desempeño (tiempo de ingesta)
    fecha_hora TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 3. TABLAS COMPLEMENTARIAS PARA CUMPLIR EL MARCO TEÓRICO Y METODOLOGÍA
-- ============================================================================

-- 3.1 Tabla: estimaciones_eta (Capa 3 y Etapa 5: Evaluación de MAE y Error Porcentual)
-- Registra el ETA calculado y permite compararlo con el tiempo real cronometrado en parada
CREATE TABLE estimaciones_eta (
    id_estimacion BIGSERIAL PRIMARY KEY,
    id_unidad INT NOT NULL REFERENCES unidades(id_unidad) ON DELETE CASCADE,
    id_parada_objetivo INT NOT NULL REFERENCES paradas(id_parada) ON DELETE CASCADE,
    distancia_restante_m NUMERIC(8,2) NOT NULL,
    velocidad_suavizada_kmh NUMERIC(5,2),         -- Velocidad tras filtro de variaciones
    condicion_trafico VARCHAR(30) DEFAULT 'fluido'
        CHECK (condicion_trafico IN ('fluido', 'moderado', 'congestion_alta')),
    fuente_calculo VARCHAR(40) DEFAULT 'PostGIS_OSRM'
        CHECK (fuente_calculo IN ('PostGIS_Base', 'Google_Distance_Matrix', 'OSRM', 'Hibrido_Suavizado')),
    eta_estimado_min NUMERIC(5,2) NOT NULL,       -- Variable dependiente: Tiempo Estimado (T_gorro)
    tiempo_real_min NUMERIC(5,2),                 -- Variable de validación en campo (T_real)
    error_absoluto_min NUMERIC(5,2) GENERATED ALWAYS AS (
        ABS(eta_estimado_min - tiempo_real_min)
    ) STORED,                                     -- Indicador: |Tiempo estimado - Tiempo real|
    error_porcentual NUMERIC(6,2) GENERATED ALWAYS AS (
        CASE WHEN tiempo_real_min > 0 
             THEN (ABS(eta_estimado_min - tiempo_real_min) / tiempo_real_min) * 100 
             ELSE NULL END
    ) STORED,                                     -- Indicador: (|T_est - T_real| / T_real) * 100
    latencia_respuesta_ms INT,                    -- Variable dependiente: Tiempo de respuesta (< 2000 ms)
    fecha_calculo TIMESTAMPTZ DEFAULT NOW()
);

-- 3.2 Tabla: incidencias_viales (Sección 1.2: Factores de incertidumbre y desvíos)
-- Registra obras públicas, accidentes o saturación en Carretera 57 / Centro Histórico
CREATE TABLE incidencias_viales (
    id_incidencia SERIAL PRIMARY KEY,
    id_ruta_afectada INT REFERENCES rutas(id_ruta) ON DELETE CASCADE,
    tipo_incidencia VARCHAR(50) NOT NULL
        CHECK (tipo_incidencia IN ('obra_publica', 'cierre_vial', 'congestion_carretera_57', 'accidente', 'desvio_temporal')),
    descripcion TEXT NOT NULL,                    -- Ej. 'Cierre por bacheo en zona centro'
    retraso_estimado_min INT DEFAULT 0,
    ubicacion_incidencia GEOMETRY(Point, 4326),
    activa BOOLEAN DEFAULT TRUE,
    fecha_reporte TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 4. ÍNDICES ESPACIALES (GIST) Y RELACIONALES PARA BAJA LATENCIA (< 50 ms)
-- ============================================================================
CREATE INDEX idx_rutas_trazado_gist ON rutas USING GIST (trazado);
CREATE INDEX idx_paradas_ubicacion_gist ON paradas USING GIST (ubicacion);
CREATE INDEX idx_unidades_ultima_pos_gist ON unidades USING GIST (ultima_posicion);
CREATE INDEX idx_coordenadas_log_geom_gist ON coordenadas_log USING GIST (punto_geom);
CREATE INDEX idx_coordenadas_log_unidad_fecha ON coordenadas_log (id_unidad, fecha_hora DESC);
CREATE INDEX idx_estimaciones_eta_unidad_parada ON estimaciones_eta (id_unidad, id_parada_objetivo);

-- ============================================================================
-- 5. TRIGGER AUTOMÁTICO: ACTUALIZAR POSICIÓN EN 'unidades' AL RECIBIR TELEMETRÍA
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_actualizar_ultima_posicion_unidad()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE unidades
    SET ultima_latitud = NEW.latitud,
        ultima_longitud = NEW.longitud,
        ultima_velocidad_kmh = NEW.velocidad_kmh,
        ultima_posicion = NEW.punto_geom,
        ultima_actualizacion = NEW.fecha_hora
    WHERE id_unidad = NEW.id_unidad;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sincronizar_posicion_unidad
AFTER INSERT ON coordenadas_log
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_ultima_posicion_unidad();

-- ============================================================================
-- 6. POLÍTICAS DE SEGURIDAD ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE rutas ENABLE ROW LEVEL SECURITY;
ALTER TABLE paradas ENABLE ROW LEVEL SECURITY;
ALTER TABLE unidades ENABLE ROW LEVEL SECURITY;
ALTER TABLE coordenadas_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE estimaciones_eta ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidencias_viales ENABLE ROW LEVEL SECURITY;

-- Políticas de lectura pública para la aplicación móvil ciudadana (Cliente)
CREATE POLICY "Lectura publica de rutas" ON rutas FOR SELECT USING (true);
CREATE POLICY "Lectura publica de paradas" ON paradas FOR SELECT USING (true);
CREATE POLICY "Lectura publica de unidades" ON unidades FOR SELECT USING (true);
CREATE POLICY "Lectura publica de telemetria" ON coordenadas_log FOR SELECT USING (true);
CREATE POLICY "Lectura publica de ETA" ON estimaciones_eta FOR SELECT USING (true);
CREATE POLICY "Lectura publica de incidencias" ON incidencias_viales FOR SELECT USING (true);

-- Políticas de inserción/actualización para el módulo transmisor GPS y pruebas
CREATE POLICY "Insercion telemetria unidades" ON coordenadas_log FOR INSERT WITH CHECK (true);
CREATE POLICY "Insercion calculo ETA" ON estimaciones_eta FOR INSERT WITH CHECK (true);
CREATE POLICY "Actualizacion posicion unidades" ON unidades FOR UPDATE USING (true);

-- ============================================================================
-- 7. CONFIGURACIÓN DE SUPABASE REALTIME (TRANSMISIÓN VÍA WEBSOCKETS)
-- ============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE unidades;
ALTER PUBLICATION supabase_realtime ADD TABLE coordenadas_log;
ALTER PUBLICATION supabase_realtime ADD TABLE estimaciones_eta;
ALTER PUBLICATION supabase_realtime ADD TABLE incidencias_viales;