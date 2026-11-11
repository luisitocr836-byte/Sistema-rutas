import {
  calcularEta,
  distanciaHaversineM,
  validarCoordenadas,
  type ConfigEta,
  type Parada,
  type ProveedorRuteo,
  type ResultadoEta,
  type Ruta,
} from '../core';
import type { RepositorioEta } from './repositorio';

export interface OpcionesServicioEta {
  proveedor: ProveedorRuteo | null;
  config: ConfigEta;
  intervaloMinimoS: number;
  lecturasParaSuavizado: number;
  /** Reloj inyectable (pruebas). */
  ahora?: () => Date;
  /** Registro de eventos; por defecto no hace nada. */
  log?: (mensaje: string) => void;
}

export type EstadoProcesamiento =
  | 'estimacion_guardada'
  | 'omitido_por_intervalo'
  | 'unidad_no_encontrada'
  | 'unidad_sin_ruta'
  | 'ruta_no_encontrada'
  | 'sin_eta'
  | 'ya_en_parada';

export interface ResultadoProcesamiento {
  estado: EstadoProcesamiento;
  detalle: string;
  eta?: ResultadoEta;
  llegadasRegistradas: number;
}

/**
 * Orquesta el flujo del Objetivo 4 para una unidad cada vez que llega una lectura:
 *   última coordenada → ruta asignada → siguiente parada → distancia vial → ETA → guardar estimación,
 *   y, si la unidad llegó a alguna parada, registrar el tiempo real observado (para el MAE).
 */
export class ServicioEta {
  private readonly ultimoCalculo = new Map<number, number>();
  private readonly cacheRutas = new Map<number, { ruta: Ruta; paradas: Parada[]; expira: number }>();
  private readonly ahora: () => Date;
  private readonly log: (m: string) => void;

  constructor(
    private readonly repo: RepositorioEta,
    private readonly opciones: OpcionesServicioEta,
  ) {
    this.ahora = opciones.ahora ?? (() => new Date());
    this.log = opciones.log ?? (() => undefined);
  }

  private async rutaConParadas(idRuta: number) {
    const ahoraMs = this.ahora().getTime();
    const cache = this.cacheRutas.get(idRuta);
    if (cache && cache.expira > ahoraMs) return cache;
    const datos = await this.repo.obtenerRutaConParadas(idRuta);
    if (!datos) return null;
    const entrada = { ...datos, expira: ahoraMs + 5 * 60_000 };
    this.cacheRutas.set(idRuta, entrada);
    return entrada;
  }

  async procesarUnidad(idUnidad: number): Promise<ResultadoProcesamiento> {
    const ahora = this.ahora();
    const ahoraMs = ahora.getTime();

    const unidad = await this.repo.obtenerUnidad(idUnidad);
    if (!unidad) return { estado: 'unidad_no_encontrada', detalle: `Unidad ${idUnidad} no existe.`, llegadasRegistradas: 0 };
    if (unidad.idRuta === null) {
      return { estado: 'unidad_sin_ruta', detalle: `La unidad ${unidad.numeroEconomico} no tiene ruta asignada.`, llegadasRegistradas: 0 };
    }
    const datosRuta = await this.rutaConParadas(unidad.idRuta);
    if (!datosRuta) return { estado: 'ruta_no_encontrada', detalle: `Ruta ${unidad.idRuta} no existe.`, llegadasRegistradas: 0 };

    const lecturas = await this.repo.obtenerLecturasRecientes(idUnidad, this.opciones.lecturasParaSuavizado);
    const ultima = lecturas.length > 0 ? lecturas[lecturas.length - 1] : undefined;

    // 1) Llegadas: se registran siempre (no dependen del intervalo de cálculo) y solo con coordenada válida y vigente.
    let llegadas = 0;
    if (ultima && validarCoordenadas(ultima.latitud, ultima.longitud).valido &&
        ahoraMs - ultima.timestampMs <= this.opciones.config.velocidad.edadMaximaMs) {
      for (const p of datosRuta.paradas) {
        if (distanciaHaversineM(ultima, p) <= this.opciones.config.radioLlegadaM) {
          llegadas += await this.repo.registrarLlegada(idUnidad, p.idParada, ahora);
        }
      }
    }

    // 2) Limitación de frecuencia por unidad.
    const previo = this.ultimoCalculo.get(idUnidad);
    if (previo !== undefined && ahoraMs - previo < this.opciones.intervaloMinimoS * 1000) {
      return { estado: 'omitido_por_intervalo', detalle: 'Cálculo omitido: intervalo mínimo no cumplido.', llegadasRegistradas: llegadas };
    }

    // 3) ETA.
    const eta = await calcularEta({
      lecturas,
      trazado: datosRuta.ruta.trazado,
      paradas: datosRuta.paradas,
      proveedor: this.opciones.proveedor,
      ahoraMs,
      config: this.opciones.config,
    });
    for (const a of eta.advertencias) this.log(`[unidad ${idUnidad}] ${a}`);

    if (eta.estado !== 'ok' || eta.paradaObjetivo === undefined || eta.etaMin === undefined || eta.distanciaRestanteM === undefined) {
      return { estado: 'sin_eta', detalle: eta.mensaje, eta, llegadasRegistradas: llegadas };
    }
    // Si ya está dentro del radio de llegada de la parada objetivo no se registra una estimación nueva.
    if (ultima && distanciaHaversineM(ultima, eta.paradaObjetivo) <= this.opciones.config.radioLlegadaM) {
      return { estado: 'ya_en_parada', detalle: `La unidad ya está en "${eta.paradaObjetivo.nombre}".`, eta, llegadasRegistradas: llegadas };
    }

    await this.repo.guardarEstimacion({
      idUnidad,
      idParadaObjetivo: eta.paradaObjetivo.idParada,
      distanciaRestanteM: eta.distanciaRestanteM,
      velocidadSuavizadaKmh: eta.velocidadSuavizadaKmh ?? null,
      condicionTrafico: eta.condicionTrafico ?? 'desconocido',
      fuenteCalculo: eta.fuenteCalculo ?? 'respaldo_ruta',
      etaEstimadoMin: eta.etaMin,
      latenciaRespuestaMs: eta.latenciaCalculoMs ?? 0,
      esSimulado: eta.esSimulado === true,
    });
    this.ultimoCalculo.set(idUnidad, ahoraMs);
    return {
      estado: 'estimacion_guardada',
      detalle: `ETA ${eta.etaMin.toFixed(2)} min hacia "${eta.paradaObjetivo.nombre}" (${eta.fuenteCalculo}).`,
      eta,
      llegadasRegistradas: llegadas,
    };
  }
}
