/**
 * Tipos del núcleo de MoviQro (sin dependencias de React Native ni de Supabase).
 * Este módulo lo comparten la app móvil, el worker ETA, el simulador GPS y las pruebas.
 *
 * Convención espacial (Avance 1, "Problemas y decisiones técnicas", punto 2):
 * en PostGIS el orden es (longitud, latitud). En el código de la app se usan
 * objetos con nombres explícitos { latitud, longitud } para evitar inversiones.
 */

export interface Coordenada {
  latitud: number;
  longitud: number;
}

/** Procedencia del dato. Permite diferenciar datos reales, estimados y simulados. */
export type OrigenDato = 'real' | 'simulado';

/** Procedencia de la geometría/catálogo (rutas, paradas, unidades). */
export type FuenteDatos = 'oficial' | 'levantamiento_equipo' | 'demostracion';

export interface LecturaGps extends Coordenada {
  /** Velocidad en km/h (ya convertida). null si el dispositivo no la reporta. */
  velocidadKmh: number | null;
  /** Precisión horizontal en metros, si está disponible. */
  precisionM: number | null;
  /** Instante de la medición (milisegundos Unix). */
  timestampMs: number;
  origen: OrigenDato;
}

export interface Parada extends Coordenada {
  idParada: number;
  idRuta: number;
  nombre: string;
  referenciaVial?: string | null;
  ordenSecuencia: number;
  esNodoTransferencia?: boolean;
}

export interface Ruta {
  idRuta: number;
  numeroRuta: string;
  nombre: string;
  origen: string;
  destino: string;
  distanciaKm: number | null;
  colorHex: string | null;
  horarioInicio: string | null;
  horarioFin: string | null;
  frecuenciaPromedioMin: number | null;
  activa: boolean;
  /** Polilínea del trazado en orden de recorrido. */
  trazado: Coordenada[];
  fuenteDatos: FuenteDatos;
}

export interface Unidad {
  idUnidad: number;
  idRuta: number | null;
  numeroEconomico: string;
  estadoOperativo: string;
  ultimaLatitud: number | null;
  ultimaLongitud: number | null;
  ultimaVelocidadKmh: number | null;
  /** ISO 8601 */
  ultimaActualizacion: string | null;
  ultimoOrigenDato: OrigenDato | null;
}

export type CondicionTrafico = 'fluido' | 'moderado' | 'denso' | 'desconocido';

export type FuenteCalculo = 'osrm' | 'google_distance_matrix' | 'respaldo_ruta';

export interface Estimacion {
  idEstimacion: number;
  idUnidad: number;
  idParadaObjetivo: number;
  distanciaRestanteM: number;
  velocidadSuavizadaKmh: number | null;
  condicionTrafico: CondicionTrafico;
  fuenteCalculo: FuenteCalculo;
  etaEstimadoMin: number;
  tiempoRealMin: number | null;
  errorAbsolutoMin: number | null;
  errorPorcentual: number | null;
  latenciaRespuestaMs: number | null;
  /** ISO 8601 */
  fechaCalculo: string;
  esSimulado: boolean;
}

export interface Incidencia {
  idIncidencia: number;
  idRutaAfectada: number | null;
  tipoIncidencia: string;
  descripcion: string;
  retrasoEstimadoMin: number | null;
  ubicacion: Coordenada | null;
  activa: boolean;
  fechaReporte: string;
  fuenteDatos: FuenteDatos;
}

/** Resultado de consultar un proveedor de ruteo vial. */
export interface RespuestaRuteo {
  distanciaM: number;
  duracionS: number;
  fuente: Exclude<FuenteCalculo, 'respaldo_ruta'>;
}

export interface ProveedorRuteo {
  readonly nombre: string;
  /** Debe lanzar un Error si el proveedor falla o no encuentra ruta. */
  obtenerRuta(origen: Coordenada, destino: Coordenada): Promise<RespuestaRuteo>;
}
