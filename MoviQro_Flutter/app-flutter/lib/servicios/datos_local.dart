import 'dart:async';

import '../core/core.dart';
import '../datos/rutas_locales.dart';
import 'proveedor_datos.dart';

/// Proveedor local: usa las rutas incluidas en la app (derivadas de datos-espaciales/*.geojson) y
/// UNIDADES SIMULADAS. Todo dato generado aquí se marca como origen simulado / es_simulado = true,
/// por lo que la interfaz lo etiqueta "Demostración". No se contacta ningún servidor.
/// Las estimaciones usan el motor ETA real (core/eta.dart) con el respaldo por trazado.
class DatosLocal implements ProveedorDatos {
  static const double _velocidadDemoKmh = 35;
  static const int _intervaloS = 3;

  final _oyentesUnidades = <void Function(Unidad)>{};
  final _oyentesEstimaciones = <void Function(Estimacion)>{};
  Timer? _temporizador;
  int _contadorEstimaciones = 0;

  late final List<Unidad> _unidades = [
    for (final r in rutasLocales)
      Unidad(
        idUnidad: 1000 + r.ruta.idRuta,
        idRuta: r.ruta.idRuta,
        numeroEconomico: 'DEMO-R${r.ruta.numeroRuta}-01',
        estadoOperativo: 'activa',
      ),
  ];

  late final List<SimuladorUnidad> _simuladores = [
    for (var i = 0; i < rutasLocales.length; i++)
      SimuladorUnidad(
        trazado: rutasLocales[i].ruta.trazado,
        velocidadKmh: _velocidadDemoKmh,
        intervaloS: _intervaloS.toDouble(),
        bucle: true,
        // Cada unidad arranca en un punto distinto para que no sean idénticas.
        inicioM: i * 500.0,
        tiempoInicialMs: DateTime.now().millisecondsSinceEpoch,
      ),
  ];

  late final List<List<LecturaGps>> _historiales = [for (final _ in rutasLocales) <LecturaGps>[]];
  bool _ocupado = false;

  @override
  ModoDatos get modo => ModoDatos.local;

  Future<void> _paso() async {
    if (_ocupado) return;
    _ocupado = true;
    try {
      for (var i = 0; i < _simuladores.length; i++) {
        final ahora = DateTime.now().millisecondsSinceEpoch;
        final l = _simuladores[i].avanzar().copiarCon(timestampMs: ahora);
        final hist = _historiales[i]..add(l);
        if (hist.length > 8) hist.removeAt(0);

        final u = _unidades[i] = _unidades[i].conPosicion(
          latitud: l.latitud,
          longitud: l.longitud,
          velocidadKmh: l.velocidadKmh,
          actualizacionIso: DateTime.fromMillisecondsSinceEpoch(l.timestampMs, isUtc: true).toIso8601String(),
          origen: l.origen,
        );
        for (final f in List.of(_oyentesUnidades)) {
          f(u);
        }

        final datos = rutasLocales[i];
        final eta = await calcularEta(
          lecturas: List.of(hist),
          trazado: datos.ruta.trazado,
          paradas: datos.paradas,
          proveedor: null,
          ahoraMs: DateTime.now().millisecondsSinceEpoch,
        );
        if (eta.estado == EstadoEta.ok && eta.paradaObjetivo != null && eta.etaMin != null && eta.distanciaRestanteM != null) {
          final e = Estimacion(
            idEstimacion: ++_contadorEstimaciones,
            idUnidad: u.idUnidad,
            idParadaObjetivo: eta.paradaObjetivo!.idParada,
            distanciaRestanteM: eta.distanciaRestanteM!,
            velocidadSuavizadaKmh: eta.velocidadSuavizadaKmh,
            condicionTrafico: eta.condicionTrafico ?? CondicionTrafico.desconocido,
            fuenteCalculo: eta.fuenteCalculo ?? FuenteCalculo.respaldoRuta,
            etaEstimadoMin: eta.etaMin!,
            latenciaRespuestaMs: eta.latenciaCalculoMs,
            fechaCalculo: DateTime.now().toUtc().toIso8601String(),
            esSimulado: true,
          );
          for (final f in List.of(_oyentesEstimaciones)) {
            f(e);
          }
        }
      }
    } finally {
      _ocupado = false;
    }
  }

  void _arrancarSiHaceFalta() {
    if (_temporizador == null && (_oyentesUnidades.isNotEmpty || _oyentesEstimaciones.isNotEmpty)) {
      _paso();
      _temporizador = Timer.periodic(const Duration(seconds: _intervaloS), (_) => _paso());
    }
  }

  void _detenerSiNadie() {
    if (_temporizador != null && _oyentesUnidades.isEmpty && _oyentesEstimaciones.isEmpty) {
      _temporizador!.cancel();
      _temporizador = null;
    }
  }

  @override
  Future<List<RutaConParadas>> listarRutas() async => List.of(rutasLocales);

  @override
  Future<List<Unidad>> listarUnidades() async => List.of(_unidades);

  @override
  Future<List<Incidencia>> listarIncidencias() async => [
        Incidencia(
          idIncidencia: 1,
          idRutaAfectada: rutasLocales.isEmpty ? null : rutasLocales.first.ruta.idRuta,
          tipoIncidencia: 'congestion',
          descripcion: 'DEMOSTRACIÓN: ejemplo de incidencia vial. No corresponde a un evento real.',
          retrasoEstimadoMin: 5,
          ubicacion: const Coordenada(20.3872, -99.9895),
          activa: true,
          fechaReporte: DateTime.now().toUtc().toIso8601String(),
          fuenteDatos: FuenteDatos.demostracion,
        ),
      ];

  @override
  Future<List<Estimacion>> ultimasEstimaciones() async => [];

  @override
  Cancelar suscribirUnidades(void Function(Unidad) alCambiar, {void Function(EstadoRealtime)? alEstado}) {
    _oyentesUnidades.add(alCambiar);
    alEstado?.call(EstadoRealtime.conectado);
    _arrancarSiHaceFalta();
    return () {
      _oyentesUnidades.remove(alCambiar);
      _detenerSiNadie();
    };
  }

  @override
  Cancelar suscribirEstimaciones(void Function(Estimacion) alLlegar) {
    _oyentesEstimaciones.add(alLlegar);
    _arrancarSiHaceFalta();
    return () {
      _oyentesEstimaciones.remove(alLlegar);
      _detenerSiNadie();
    };
  }
}
