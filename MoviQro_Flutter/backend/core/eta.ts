import { distanciaHaversineM, validarCoordenadas } from './geo';
import { seleccionarSiguienteParada } from './siguienteParada';
import {
  CONFIG_VELOCIDAD_POR_DEFECTO,
  clasificarCondicionTrafico,
  esRegistroAntiguo,
  estaDetenida,
  suavizarVelocidadKmh,
  velocidadEsConfiable,
  type ConfigVelocidad,
} from './velocidad';
import type { CondicionTrafico, Coordenada, FuenteCalculo, LecturaGps, Parada, ProveedorRuteo } from './types';

export interface ConfigEta {
  velocidad: ConfigVelocidad;
  /**
   * Peso (0..1) de la duración vial del proveedor frente a la duración basada en la
   * velocidad del vehículo cuando ambas existen. 1 = solo proveedor.
   * VALOR INICIAL SIN CALIBRAR: debe ajustarse con el MAE de la validación de campo.
   */
  pesoProveedor: number;
  /**
   * Velocidad media (km/h) que se usa SOLO en el respaldo cuando el proveedor falla y la
   * unidad no tiene velocidad confiable. Supuesto configurable, sin calibrar.
   */
  velocidadRespaldoKmh: number;
  /** Velocidad de referencia (km/h) para clasificar la condición de tráfico. */
  velocidadReferenciaKmh: number;
  /** Margen en metros para considerar que la unidad llegó a la parada. */
  radioLlegadaM: number;
}

export const CONFIG_ETA_POR_DEFECTO: ConfigEta = {
  velocidad: CONFIG_VELOCIDAD_POR_DEFECTO,
  pesoProveedor: 0.6,
  velocidadRespaldoKmh: 15,
  velocidadReferenciaKmh: 30,
  radioLlegadaM: 40,
};

export type EstadoEta =
  | 'ok'
  | 'sin_datos_gps'
  | 'coordenada_invalida'
  | 'registro_antiguo'
  | 'sin_ruta'
  | 'sin_parada_pendiente';

export interface EntradaEta {
  /** Lecturas recientes de la unidad en orden cronológico ascendente (la última es la más reciente). */
  lecturas: LecturaGps[];
  trazado: Coordenada[];
  paradas: Parada[];
  proveedor: ProveedorRuteo | null;
  ahoraMs: number;
  config?: ConfigEta;
}

export interface ResultadoEta {
  estado: EstadoEta;
  mensaje: string;
  /** Presentes solo cuando estado === 'ok'. */
  paradaObjetivo?: Parada;
  etaMin?: number;
  distanciaRestanteM?: number;
  velocidadSuavizadaKmh?: number | null;
  condicionTrafico?: CondicionTrafico;
  fuenteCalculo?: FuenteCalculo;
  unidadDetenida?: boolean;
  /** true si la lectura base fue simulada (se debe etiquetar "Demostración"). */
  esSimulado?: boolean;
  /** Avisos no fatales (p. ej. falló el proveedor y se usó el respaldo). */
  advertencias: string[];
  latenciaCalculoMs?: number;
}

const segundosAMin = (s: number) => s / 60;

/**
 * Motor de estimación ETA (Objetivo específico 4, Etapa 4).
 *
 * 1. Toma la última coordenada válida de la unidad.
 * 2. Descarta registros antiguos o inválidos (no inventa un ETA).
 * 3. Determina la siguiente parada relevante sobre el trazado de la ruta asignada.
 * 4. Consulta distancia y duración vial al proveedor (OSRM / Google). Si falla, usa un
 *    respaldo basado en la distancia por el trazado de la ruta.
 * 5. Combina la duración vial con la velocidad suavizada del vehículo cuando ésta es
 *    confiable y la unidad está en movimiento. Si está detenida, usa solo la duración vial
 *    (no se divide entre una velocidad ≈ 0).
 *
 * No genera valores aleatorios. Si no hay datos suficientes devuelve un estado explícito.
 */
export async function calcularEta(entrada: EntradaEta): Promise<ResultadoEta> {
  const t0 = Date.now();
  const config = entrada.config ?? CONFIG_ETA_POR_DEFECTO;
  const advertencias: string[] = [];

  const ultima = entrada.lecturas.length > 0 ? entrada.lecturas[entrada.lecturas.length - 1] : undefined;
  if (!ultima) {
    return { estado: 'sin_datos_gps', mensaje: 'Aún no hay posiciones GPS de esta unidad.', advertencias };
  }
  const valid = validarCoordenadas(ultima.latitud, ultima.longitud);
  if (!valid.valido) {
    return { estado: 'coordenada_invalida', mensaje: valid.motivo ?? 'Coordenada inválida.', advertencias };
  }
  if (esRegistroAntiguo(ultima, entrada.ahoraMs, config.velocidad)) {
    const seg = Math.round((entrada.ahoraMs - ultima.timestampMs) / 1000);
    return {
      estado: 'registro_antiguo',
      mensaje: `La última posición tiene ${seg} s de antigüedad; no se calcula ETA con datos viejos.`,
      advertencias,
    };
  }
  if (entrada.trazado.length < 2) {
    return { estado: 'sin_ruta', mensaje: 'La ruta asignada no tiene trazado disponible.', advertencias };
  }

  const siguiente = seleccionarSiguienteParada(entrada.trazado, entrada.paradas, ultima);
  if (!siguiente) {
    return {
      estado: 'sin_parada_pendiente',
      mensaje: 'No hay paradas pendientes (la unidad ya rebasó la última parada o no hay paradas).',
      advertencias,
    };
  }

  const lecturasValidas = entrada.lecturas.filter((l) => validarCoordenadas(l.latitud, l.longitud).valido);
  const velocidadSuavizada = suavizarVelocidadKmh(lecturasValidas, config.velocidad);
  const detenida = estaDetenida(velocidadSuavizada, config.velocidad);
  const velConfiable = velocidadEsConfiable(ultima, config.velocidad) && velocidadSuavizada !== null;

  let distanciaM = siguiente.distanciaPorRutaM;
  let duracionVialMin: number | null = null;
  let fuente: FuenteCalculo = 'respaldo_ruta';

  if (entrada.proveedor) {
    try {
      const r = await entrada.proveedor.obtenerRuta(ultima, siguiente.parada);
      distanciaM = r.distanciaM;
      duracionVialMin = segundosAMin(r.duracionS);
      fuente = r.fuente;
    } catch (e) {
      const motivo = e instanceof Error ? e.message : String(e);
      advertencias.push(`Proveedor de ruteo no disponible (${motivo}); se usó el respaldo por trazado.`);
    }
  } else {
    advertencias.push('No hay proveedor de ruteo configurado; se usó el respaldo por trazado.');
  }

  let etaMin: number;
  const velParaTiempo = velocidadSuavizada !== null && velocidadSuavizada >= config.velocidad.umbralDetenidaKmh
    ? velocidadSuavizada
    : null;

  if (duracionVialMin !== null) {
    if (velConfiable && !detenida && velParaTiempo !== null) {
      const duracionVehiculoMin = distanciaM / 1000 / velParaTiempo * 60;
      etaMin = config.pesoProveedor * duracionVialMin + (1 - config.pesoProveedor) * duracionVehiculoMin;
    } else {
      etaMin = duracionVialMin;
      if (detenida) advertencias.push('La unidad está detenida; el ETA usa solo la duración vial y puede subestimar la espera.');
    }
  } else {
    // Respaldo: distancia por trazado ÷ velocidad (del vehículo si es confiable; si no, supuesto configurable).
    let velKmh: number;
    if (velConfiable && velParaTiempo !== null) {
      velKmh = velParaTiempo;
    } else {
      velKmh = config.velocidadRespaldoKmh;
      advertencias.push(`Sin velocidad confiable: se asumió ${config.velocidadRespaldoKmh} km/h (supuesto configurable).`);
    }
    etaMin = distanciaM / 1000 / velKmh * 60;
  }

  return {
    estado: 'ok',
    mensaje: 'ETA calculado.',
    paradaObjetivo: siguiente.parada,
    etaMin,
    distanciaRestanteM: distanciaM,
    velocidadSuavizadaKmh: velocidadSuavizada,
    condicionTrafico: clasificarCondicionTrafico(velocidadSuavizada, config.velocidadReferenciaKmh),
    fuenteCalculo: fuente,
    unidadDetenida: detenida,
    esSimulado: ultima.origen === 'simulado',
    advertencias,
    latenciaCalculoMs: Date.now() - t0,
  };
}

/** ¿La unidad está dentro del radio de llegada de la parada? (distancia en línea recta, solo para detectar llegada) */
export function haLlegadoAParada(posicion: Coordenada, parada: Coordenada, radioM: number): boolean {
  return distanciaHaversineM(posicion, parada) <= radioM;
}
