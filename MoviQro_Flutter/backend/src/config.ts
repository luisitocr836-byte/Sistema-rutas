import { CONFIG_ETA_POR_DEFECTO, ProveedorGoogleDistanceMatrix, ProveedorOsrm, type ConfigEta, type ProveedorRuteo } from '../core';

export interface ConfigWorker {
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  proveedor: 'osrm' | 'google' | 'none';
  osrmBaseUrl: string;
  googleApiKey: string | null;
  timeoutProveedorMs: number;
  /** Intervalo mínimo (s) entre cálculos ETA de una misma unidad. */
  intervaloMinimoS: number;
  /** Cuántas lecturas recientes se usan para suavizar la velocidad. */
  lecturasParaSuavizado: number;
  eta: ConfigEta;
}

type Env = Record<string, string | undefined>;

function numero(env: Env, clave: string, porDefecto: number, min: number, max: number): number {
  const bruto = env[clave];
  if (bruto === undefined || bruto.trim() === '') return porDefecto;
  const n = Number(bruto);
  if (!Number.isFinite(n) || n < min || n > max) {
    throw new Error(`${clave} debe ser un número entre ${min} y ${max} (valor recibido: "${bruto}").`);
  }
  return n;
}

/**
 * Lee y valida la configuración del worker desde variables de entorno.
 * No imprime ni devuelve secretos en mensajes de error.
 */
export function cargarConfigWorker(env: Env): ConfigWorker {
  const url = env.SUPABASE_URL?.trim() ?? '';
  const llave = env.SUPABASE_SERVICE_ROLE_KEY?.trim() ?? '';
  if (!/^https?:\/\//.test(url)) throw new Error('Falta SUPABASE_URL (debe iniciar con https://).');
  if (llave === '') throw new Error('Falta SUPABASE_SERVICE_ROLE_KEY (solo para servidor; nunca en la app).');

  const proveedor = (env.ETA_PROVIDER?.trim().toLowerCase() || 'osrm') as ConfigWorker['proveedor'];
  if (!['osrm', 'google', 'none'].includes(proveedor)) {
    throw new Error('ETA_PROVIDER debe ser osrm, google o none.');
  }
  const googleApiKey = env.GOOGLE_MAPS_API_KEY?.trim() || null;
  if (proveedor === 'google' && !googleApiKey) throw new Error('ETA_PROVIDER=google requiere GOOGLE_MAPS_API_KEY.');

  const base = CONFIG_ETA_POR_DEFECTO;
  return {
    supabaseUrl: url,
    supabaseServiceRoleKey: llave,
    proveedor,
    osrmBaseUrl: env.OSRM_BASE_URL?.trim() || 'https://router.project-osrm.org',
    googleApiKey,
    timeoutProveedorMs: numero(env, 'ETA_TIMEOUT_PROVEEDOR_MS', 4000, 500, 30000),
    intervaloMinimoS: numero(env, 'ETA_INTERVALO_MINIMO_S', 5, 1, 300),
    lecturasParaSuavizado: numero(env, 'ETA_LECTURAS_SUAVIZADO', 8, 1, 50),
    eta: {
      ...base,
      pesoProveedor: numero(env, 'ETA_PESO_PROVEEDOR', base.pesoProveedor, 0, 1),
      velocidadRespaldoKmh: numero(env, 'ETA_VELOCIDAD_RESPALDO_KMH', base.velocidadRespaldoKmh, 3, 80),
      velocidadReferenciaKmh: numero(env, 'ETA_VELOCIDAD_REFERENCIA_KMH', base.velocidadReferenciaKmh, 5, 120),
      radioLlegadaM: numero(env, 'ETA_RADIO_LLEGADA_M', base.radioLlegadaM, 10, 200),
      velocidad: {
        ...base.velocidad,
        edadMaximaMs: numero(env, 'ETA_EDAD_MAXIMA_S', base.velocidad.edadMaximaMs / 1000, 5, 600) * 1000,
      },
    },
  };
}

export function crearProveedor(cfg: ConfigWorker): ProveedorRuteo | null {
  switch (cfg.proveedor) {
    case 'osrm':
      return new ProveedorOsrm(cfg.osrmBaseUrl, { timeoutMs: cfg.timeoutProveedorMs });
    case 'google':
      return new ProveedorGoogleDistanceMatrix(cfg.googleApiKey as string, { timeoutMs: cfg.timeoutProveedorMs });
    default:
      return null;
  }
}
