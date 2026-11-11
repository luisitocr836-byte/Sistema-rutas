import { describe, expect, it } from 'vitest';
import { CONFIG_ETA_POR_DEFECTO, proyectarEnRuta, type LecturaGps, type ObservacionEta, type Parada, type Ruta, type Unidad } from '../core';
import type { NuevaEstimacion, RepositorioEta } from '../src/repositorio';
import { ServicioEta } from '../src/servicioEta';
import { AHORA, PARADAS, RUTA, lectura, proveedorFijo, proveedorQueFalla, unidadBase } from './helpers';

class RepoMemoria implements RepositorioEta {
  estimaciones: NuevaEstimacion[] = [];
  llegadas: { idUnidad: number; idParada: number; momento: Date }[] = [];
  constructor(
    public unidad: Unidad | null = unidadBase,
    public lecturas: LecturaGps[] = [],
    public ruta: { ruta: Ruta; paradas: Parada[] } | null = { ruta: RUTA, paradas: PARADAS },
  ) {}
  async obtenerUnidad() { return this.unidad; }
  async obtenerRutaConParadas() { return this.ruta; }
  async obtenerLecturasRecientes() { return this.lecturas; }
  async guardarEstimacion(e: NuevaEstimacion) { this.estimaciones.push(e); }
  async registrarLlegada(idUnidad: number, idParada: number, momento: Date) { this.llegadas.push({ idUnidad, idParada, momento }); return 1; }
  async obtenerObservaciones(): Promise<ObservacionEta[]> { return []; }
}

const posParada = (o: number) => proyectarEnRuta(RUTA.trazado, PARADAS.find((p) => p.ordenSecuencia === o)!).distanciaAlolargoM;

function crear(repo: RepoMemoria, proveedor = proveedorFijo(), reloj = { t: AHORA }) {
  const servicio = new ServicioEta(repo, {
    proveedor,
    config: CONFIG_ETA_POR_DEFECTO,
    intervaloMinimoS: 5,
    lecturasParaSuavizado: 8,
    ahora: () => new Date(reloj.t),
  });
  return { servicio, reloj };
}

describe('ServicioEta.procesarUnidad', () => {
  it('flujo completo: última coordenada → siguiente parada → ETA → estimación guardada', async () => {
    const repo = new RepoMemoria(unidadBase, [lectura(posParada(2) + 200)]);
    const { servicio } = crear(repo);
    const r = await servicio.procesarUnidad(1);
    expect(r.estado).toBe('estimacion_guardada');
    expect(repo.estimaciones).toHaveLength(1);
    const e = repo.estimaciones[0];
    expect(e.idParadaObjetivo).toBe(PARADAS.find((p) => p.ordenSecuencia === 3)!.idParada);
    expect(e.fuenteCalculo).toBe('osrm');
    expect(e.etaEstimadoMin).toBeGreaterThan(0);
    expect(e.esSimulado).toBe(false);
  });
  it('lecturas simuladas se guardan marcadas como es_simulado = true', async () => {
    const repo = new RepoMemoria(unidadBase, [lectura(posParada(2) + 200, { origen: 'simulado' })]);
    await crear(repo).servicio.procesarUnidad(1);
    expect(repo.estimaciones[0].esSimulado).toBe(true);
  });
  it('respeta el intervalo mínimo por unidad', async () => {
    const repo = new RepoMemoria(unidadBase, [lectura(posParada(2) + 200)]);
    const { servicio, reloj } = crear(repo);
    expect((await servicio.procesarUnidad(1)).estado).toBe('estimacion_guardada');
    reloj.t += 2_000;
    expect((await servicio.procesarUnidad(1)).estado).toBe('omitido_por_intervalo');
    reloj.t += 4_000; // ya pasaron 6 s
    repo.lecturas = [lectura(posParada(2) + 300, { timestampMs: reloj.t - 1000 })];
    expect((await servicio.procesarUnidad(1)).estado).toBe('estimacion_guardada');
    expect(repo.estimaciones).toHaveLength(2);
  });
  it('si el proveedor falla igualmente guarda la estimación con fuente respaldo_ruta', async () => {
    const repo = new RepoMemoria(unidadBase, [lectura(posParada(2) + 200)]);
    const r = await crear(repo, proveedorQueFalla as never).servicio.procesarUnidad(1);
    expect(r.estado).toBe('estimacion_guardada');
    expect(repo.estimaciones[0].fuenteCalculo).toBe('respaldo_ruta');
  });
  it('datos faltantes: unidad inexistente, sin ruta, ruta inexistente, sin lecturas, registro antiguo', async () => {
    expect((await crear(new RepoMemoria(null)).servicio.procesarUnidad(1)).estado).toBe('unidad_no_encontrada');
    expect((await crear(new RepoMemoria({ ...unidadBase, idRuta: null })).servicio.procesarUnidad(1)).estado).toBe('unidad_sin_ruta');
    expect((await crear(new RepoMemoria(unidadBase, [], null)).servicio.procesarUnidad(1)).estado).toBe('ruta_no_encontrada');
    const sinLecturas = new RepoMemoria(unidadBase, []);
    expect((await crear(sinLecturas).servicio.procesarUnidad(1)).estado).toBe('sin_eta');
    const viejo = new RepoMemoria(unidadBase, [lectura(500, { timestampMs: AHORA - 300_000 })]);
    const r = await crear(viejo).servicio.procesarUnidad(1);
    expect(r.estado).toBe('sin_eta');
    expect(viejo.estimaciones).toHaveLength(0);
  });
  it('registra la llegada (tiempo real observado) cuando la unidad entra al radio de una parada', async () => {
    const repo = new RepoMemoria(unidadBase, [lectura(posParada(3) + 5)]);
    const r = await crear(repo).servicio.procesarUnidad(1);
    expect(repo.llegadas).toHaveLength(1);
    expect(repo.llegadas[0].idParada).toBe(PARADAS.find((p) => p.ordenSecuencia === 3)!.idParada);
    expect(r.llegadasRegistradas).toBe(1);
    expect(r.estado).toBe('ya_en_parada'); // no se crea una estimación hacia la parada donde ya está
    expect(repo.estimaciones).toHaveLength(0);
  });
  it('no registra llegadas con una lectura antigua', async () => {
    const repo = new RepoMemoria(unidadBase, [lectura(posParada(3) + 5, { timestampMs: AHORA - 600_000 })]);
    await crear(repo).servicio.procesarUnidad(1);
    expect(repo.llegadas).toHaveLength(0);
  });
});
