import { RUTAS_LOCALES } from '../core/rutasLocales';
import {
  puntoAlolargoDeRuta,
  longitudPolilineaM,
  type Coordenada,
  type LecturaGps,
  type Parada,
  type ProveedorRuteo,
  type RespuestaRuteo,
  type Ruta,
  type Unidad,
} from '../core';

/** Ruta 38 demostrativa (generada desde datos-espaciales/ruta_38.geojson). */
export const RUTA_38 = RUTAS_LOCALES.find((r) => r.ruta.numeroRuta === '38')!;
export const RUTA: Ruta = RUTA_38.ruta;
export const PARADAS: Parada[] = RUTA_38.paradas.map((p) => ({ ...p }));
export const LARGO_RUTA_M = longitudPolilineaM(RUTA.trazado);

export const AHORA = 1_800_000_000_000; // instante fijo para pruebas deterministas

/** Punto situado a `m` metros del inicio de la ruta. */
export const enRuta = (m: number): Coordenada => puntoAlolargoDeRuta(RUTA.trazado, m);

export function lectura(m: number, extra: Partial<LecturaGps> = {}): LecturaGps {
  const p = enRuta(m);
  return {
    latitud: p.latitud,
    longitud: p.longitud,
    velocidadKmh: 20,
    precisionM: 5,
    timestampMs: AHORA - 2_000,
    origen: 'real',
    ...extra,
  };
}

export function proveedorFijo(r: Partial<RespuestaRuteo> = {}): ProveedorRuteo & { llamadas: number } {
  return {
    nombre: 'fijo',
    llamadas: 0,
    async obtenerRuta() {
      this.llamadas++;
      return { distanciaM: 1000, duracionS: 120, fuente: 'osrm', ...r };
    },
  };
}

export const proveedorQueFalla: ProveedorRuteo = {
  nombre: 'falla',
  async obtenerRuta() {
    throw new Error('servicio no disponible');
  },
};

export const unidadBase: Unidad = {
  idUnidad: 1,
  idRuta: RUTA.idRuta,
  numeroEconomico: 'DEMO-R38-01',
  estadoOperativo: 'activa',
  ultimaLatitud: null,
  ultimaLongitud: null,
  ultimaVelocidadKmh: null,
  ultimaActualizacion: null,
  ultimoOrigenDato: null,
};
