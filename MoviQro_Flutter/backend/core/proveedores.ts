import type { Coordenada, ProveedorRuteo, RespuestaRuteo } from './types';

export type FetchLike = (
  url: string,
  init?: { signal?: AbortSignal },
) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>;

export interface OpcionesProveedor {
  /** Tiempo máximo de espera por consulta (ms). */
  timeoutMs: number;
  fetchImpl?: FetchLike;
}

const OPCIONES_POR_DEFECTO: OpcionesProveedor = { timeoutMs: 4000 };

async function pedirJson(url: string, opciones: OpcionesProveedor): Promise<unknown> {
  const fetchFn: FetchLike = opciones.fetchImpl ?? ((globalThis as unknown as { fetch: FetchLike }).fetch);
  const controlador = new AbortController();
  const temporizador = setTimeout(() => controlador.abort(), opciones.timeoutMs);
  try {
    const resp = await fetchFn(url, { signal: controlador.signal });
    if (!resp.ok) throw new Error(`El proveedor respondió HTTP ${resp.status}.`);
    return await resp.json();
  } catch (e) {
    if (controlador.signal.aborted) throw new Error(`Tiempo de espera agotado (${opciones.timeoutMs} ms).`);
    throw e;
  } finally {
    clearTimeout(temporizador);
  }
}

function esNumeroPositivoOCero(x: unknown): x is number {
  return typeof x === 'number' && Number.isFinite(x) && x >= 0;
}

/**
 * Proveedor OSRM (Open Source Routing Machine) vía API HTTP /route/v1.
 *
 * ⚠ El servidor público https://router.project-osrm.org es solo de demostración
 * (sin garantías de disponibilidad ni uso intensivo). Para validación real se
 * recomienda una instancia propia. Se configura con OSRM_BASE_URL.
 * OSRM no incorpora tráfico en vivo: su duración es "sin tráfico".
 */
export class ProveedorOsrm implements ProveedorRuteo {
  readonly nombre = 'osrm';
  private readonly baseUrl: string;
  private readonly opciones: OpcionesProveedor;

  constructor(baseUrl: string, opciones: Partial<OpcionesProveedor> = {}) {
    if (!/^https?:\/\//.test(baseUrl)) throw new Error('OSRM_BASE_URL debe iniciar con http:// o https://');
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.opciones = { ...OPCIONES_POR_DEFECTO, ...opciones };
  }

  async obtenerRuta(origen: Coordenada, destino: Coordenada): Promise<RespuestaRuteo> {
    // OSRM espera lon,lat (mismo orden que PostGIS).
    const coords = `${origen.longitud},${origen.latitud};${destino.longitud},${destino.latitud}`;
    const url = `${this.baseUrl}/route/v1/driving/${coords}?overview=false&alternatives=false&steps=false`;
    const datos = (await pedirJson(url, this.opciones)) as {
      code?: string;
      routes?: { distance?: unknown; duration?: unknown }[];
    };
    if (datos.code !== 'Ok' || !datos.routes || datos.routes.length === 0) {
      throw new Error(`OSRM no devolvió ruta (code=${String(datos.code)}).`);
    }
    const { distance, duration } = datos.routes[0];
    if (!esNumeroPositivoOCero(distance) || !esNumeroPositivoOCero(duration)) {
      throw new Error('Respuesta de OSRM con distancia/duración inválidas.');
    }
    return { distanciaM: distance, duracionS: duration, fuente: 'osrm' };
  }
}

/**
 * Proveedor Google Maps Distance Matrix (opcional). Requiere clave (GOOGLE_MAPS_API_KEY)
 * y debe ejecutarse del lado servidor (worker), nunca embebido en la app.
 * Usa duration_in_traffic cuando Google la devuelve.
 */
export class ProveedorGoogleDistanceMatrix implements ProveedorRuteo {
  readonly nombre = 'google_distance_matrix';
  private readonly opciones: OpcionesProveedor;

  constructor(
    private readonly apiKey: string,
    opciones: Partial<OpcionesProveedor> = {},
  ) {
    if (!apiKey) throw new Error('Falta GOOGLE_MAPS_API_KEY.');
    this.opciones = { ...OPCIONES_POR_DEFECTO, ...opciones };
  }

  async obtenerRuta(origen: Coordenada, destino: Coordenada): Promise<RespuestaRuteo> {
    const params = new URLSearchParams({
      origins: `${origen.latitud},${origen.longitud}`,
      destinations: `${destino.latitud},${destino.longitud}`,
      mode: 'driving',
      departure_time: 'now',
      key: this.apiKey,
    });
    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?${params.toString()}`;
    const datos = (await pedirJson(url, this.opciones)) as {
      status?: string;
      rows?: {
        elements?: {
          status?: string;
          distance?: { value?: unknown };
          duration?: { value?: unknown };
          duration_in_traffic?: { value?: unknown };
        }[];
      }[];
    };
    const el = datos.rows?.[0]?.elements?.[0];
    if (datos.status !== 'OK' || !el || el.status !== 'OK') {
      throw new Error(`Distance Matrix sin resultado (status=${String(datos.status)}/${String(el?.status)}).`);
    }
    const distancia = el.distance?.value;
    const duracion = el.duration_in_traffic?.value ?? el.duration?.value;
    if (!esNumeroPositivoOCero(distancia) || !esNumeroPositivoOCero(duracion)) {
      throw new Error('Respuesta de Distance Matrix con valores inválidos.');
    }
    return { distanciaM: distancia, duracionS: duracion, fuente: 'google_distance_matrix' };
  }
}
