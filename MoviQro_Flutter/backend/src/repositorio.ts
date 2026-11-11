import type { SupabaseClient } from '@supabase/supabase-js';
import {
  lineStringGeoJsonACoordenadas,
  type CondicionTrafico,
  type FuenteCalculo,
  type LecturaGps,
  type ObservacionEta,
  type Parada,
  type Ruta,
  type Unidad,
} from '../core';

export interface NuevaEstimacion {
  idUnidad: number;
  idParadaObjetivo: number;
  distanciaRestanteM: number;
  velocidadSuavizadaKmh: number | null;
  condicionTrafico: CondicionTrafico;
  fuenteCalculo: FuenteCalculo;
  etaEstimadoMin: number;
  latenciaRespuestaMs: number;
  esSimulado: boolean;
}

/** Acceso a datos que necesita el servicio ETA. Se abstrae para poder probarlo sin red. */
export interface RepositorioEta {
  obtenerUnidad(idUnidad: number): Promise<Unidad | null>;
  obtenerRutaConParadas(idRuta: number): Promise<{ ruta: Ruta; paradas: Parada[] } | null>;
  /** Lecturas más recientes de la unidad, en orden cronológico ascendente. */
  obtenerLecturasRecientes(idUnidad: number, limite: number): Promise<LecturaGps[]>;
  guardarEstimacion(e: NuevaEstimacion): Promise<void>;
  /** Registra el tiempo real observado en las estimaciones pendientes. Devuelve cuántas actualizó. */
  registrarLlegada(idUnidad: number, idParada: number, momento: Date): Promise<number>;
  obtenerObservaciones(idRuta?: number, incluirSimulados?: boolean): Promise<ObservacionEta[]>;
}

function aError(contexto: string, error: { message: string } | null): never {
  // Mensaje acotado: no se vuelca el objeto de error completo (podría incluir URL/cabeceras).
  throw new Error(`${contexto}: ${error?.message ?? 'error desconocido'}`);
}

/** Implementación sobre Supabase. Requiere un cliente con service_role (solo servidor). */
export class RepositorioSupabase implements RepositorioEta {
  constructor(private readonly db: SupabaseClient) {}

  async obtenerUnidad(idUnidad: number): Promise<Unidad | null> {
    const { data, error } = await this.db.from('unidades').select('*').eq('id_unidad', idUnidad).maybeSingle();
    if (error) aError('No se pudo leer la unidad', error);
    if (!data) return null;
    return {
      idUnidad: data.id_unidad,
      idRuta: data.id_ruta,
      numeroEconomico: data.numero_economico,
      estadoOperativo: data.estado_operativo,
      ultimaLatitud: data.ultima_latitud,
      ultimaLongitud: data.ultima_longitud,
      ultimaVelocidadKmh: data.ultima_velocidad_kmh,
      ultimaActualizacion: data.ultima_actualizacion,
      ultimoOrigenDato: data.ultimo_origen_dato,
    };
  }

  async obtenerRutaConParadas(idRuta: number): Promise<{ ruta: Ruta; paradas: Parada[] } | null> {
    const { data: r, error: e1 } = await this.db.from('v_rutas').select('*').eq('id_ruta', idRuta).maybeSingle();
    if (e1) aError('No se pudo leer la ruta', e1);
    if (!r) return null;
    const { data: ps, error: e2 } = await this.db.from('v_paradas').select('*').eq('id_ruta', idRuta).order('orden_secuencia');
    if (e2) aError('No se pudieron leer las paradas', e2);
    const ruta: Ruta = {
      idRuta: r.id_ruta,
      numeroRuta: r.numero_ruta,
      nombre: r.nombre,
      origen: r.origen,
      destino: r.destino,
      distanciaKm: r.distancia_km,
      colorHex: r.color_hex,
      horarioInicio: r.horario_inicio,
      horarioFin: r.horario_fin,
      frecuenciaPromedioMin: r.frecuencia_promedio_min,
      activa: r.activa,
      trazado: lineStringGeoJsonACoordenadas(r.trazado_geojson),
      fuenteDatos: r.fuente_datos,
    };
    const paradas: Parada[] = (ps ?? []).map((p) => ({
      idParada: p.id_parada,
      idRuta: p.id_ruta,
      nombre: p.nombre,
      referenciaVial: p.referencia_vial,
      ordenSecuencia: p.orden_secuencia,
      esNodoTransferencia: p.es_nodo_transferencia,
      latitud: p.latitud,
      longitud: p.longitud,
    }));
    return { ruta, paradas };
  }

  async obtenerLecturasRecientes(idUnidad: number, limite: number): Promise<LecturaGps[]> {
    const { data, error } = await this.db
      .from('coordenadas_log')
      .select('latitud, longitud, velocidad_kmh, precision_gps_m, fecha_hora, origen_dato')
      .eq('id_unidad', idUnidad)
      .order('fecha_hora', { ascending: false })
      .limit(limite);
    if (error) aError('No se pudieron leer las lecturas', error);
    return (data ?? [])
      .map((l) => ({
        latitud: l.latitud,
        longitud: l.longitud,
        velocidadKmh: l.velocidad_kmh,
        precisionM: l.precision_gps_m,
        timestampMs: new Date(l.fecha_hora).getTime(),
        origen: l.origen_dato,
      }))
      .reverse();
  }

  async guardarEstimacion(e: NuevaEstimacion): Promise<void> {
    const { error } = await this.db.from('estimaciones_eta').insert({
      id_unidad: e.idUnidad,
      id_parada_objetivo: e.idParadaObjetivo,
      distancia_restante_m: Math.round(e.distanciaRestanteM * 100) / 100,
      velocidad_suavizada_kmh: e.velocidadSuavizadaKmh === null ? null : Math.round(e.velocidadSuavizadaKmh * 100) / 100,
      condicion_trafico: e.condicionTrafico,
      fuente_calculo: e.fuenteCalculo,
      eta_estimado_min: Math.round(e.etaEstimadoMin * 100) / 100,
      latencia_respuesta_ms: Math.round(e.latenciaRespuestaMs),
      es_simulado: e.esSimulado,
    });
    if (error) aError('No se pudo guardar la estimación', error);
  }

  async registrarLlegada(idUnidad: number, idParada: number, momento: Date): Promise<number> {
    const { data, error } = await this.db.rpc('fn_registrar_llegada', {
      p_id_unidad: idUnidad,
      p_id_parada: idParada,
      p_momento: momento.toISOString(),
    });
    if (error) aError('No se pudo registrar la llegada', error);
    return typeof data === 'number' ? data : 0;
  }

  async obtenerObservaciones(idRuta?: number, incluirSimulados = false): Promise<ObservacionEta[]> {
    let q = this.db
      .from('estimaciones_eta')
      .select('eta_estimado_min, tiempo_real_min, es_simulado, unidades!inner(id_ruta)')
      .not('tiempo_real_min', 'is', null);
    if (!incluirSimulados) q = q.eq('es_simulado', false);
    if (idRuta !== undefined) q = q.eq('unidades.id_ruta', idRuta);
    const { data, error } = await q;
    if (error) aError('No se pudieron leer las observaciones', error);
    return (data ?? []).map((o) => ({
      etaEstimadoMin: Number(o.eta_estimado_min),
      tiempoRealMin: o.tiempo_real_min === null ? null : Number(o.tiempo_real_min),
    }));
  }
}
