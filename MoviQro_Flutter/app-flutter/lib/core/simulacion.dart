import 'geo.dart';
import 'tipos.dart';

/// Generador de posiciones simuladas a lo largo de un trazado (modo "Demostración").
/// Toda lectura producida lleva origen = simulado. Es determinista: no usa aleatoriedad.
class SimuladorUnidad {
  final List<Coordenada> trazado;
  final double velocidadKmh;
  final double intervaloS;
  final bool bucle;
  late final double largoTrazadoM;
  double _distanciaM;
  int _tiempoMs;

  SimuladorUnidad({
    required this.trazado,
    required this.velocidadKmh,
    required this.intervaloS,
    required this.bucle,
    double inicioM = 0,
    required int tiempoInicialMs,
  })  : _distanciaM = inicioM,
        _tiempoMs = tiempoInicialMs {
    if (trazado.length < 2) throw ArgumentError('El trazado necesita al menos 2 puntos.');
    if (!(velocidadKmh > 0)) throw ArgumentError('La velocidad simulada debe ser mayor que 0.');
    if (!(intervaloS > 0)) throw ArgumentError('El intervalo debe ser mayor que 0.');
    largoTrazadoM = longitudPolilineaM(trazado);
    if (_distanciaM > largoTrazadoM) _distanciaM = largoTrazadoM;
  }

  bool get terminado => !bucle && _distanciaM >= largoTrazadoM;

  /// Lectura en el instante actual (sin avanzar).
  LecturaGps actual() {
    final p = puntoAlolargoDeRuta(trazado, _distanciaM);
    return LecturaGps(
      latitud: p.latitud,
      longitud: p.longitud,
      velocidadKmh: terminado ? 0 : velocidadKmh,
      precisionM: 5,
      timestampMs: _tiempoMs,
      origen: OrigenDato.simulado,
    );
  }

  /// Avanza [intervaloS] segundos de tiempo simulado y devuelve la nueva lectura.
  LecturaGps avanzar() {
    _tiempoMs += (intervaloS * 1000).round();
    _distanciaM += kmhAMs(velocidadKmh) * intervaloS;
    if (_distanciaM >= largoTrazadoM) {
      _distanciaM = bucle ? _distanciaM % largoTrazadoM : largoTrazadoM;
    }
    return actual();
  }
}
