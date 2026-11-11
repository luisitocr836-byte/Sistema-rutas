import 'package:flutter_test/flutter_test.dart';
import 'package:moviqro/core/core.dart';
import 'package:moviqro/datos/rutas_locales.dart';

void main() {
  final trazado = rutasLocales.first.ruta.trazado;

  test('toda lectura simulada lleva origen simulado y avanza el tiempo', () {
    final s = SimuladorUnidad(trazado: trazado, velocidadKmh: 36, intervaloS: 4, bucle: false, tiempoInicialMs: 1000);
    final a = s.actual();
    final b = s.avanzar();
    expect(a.origen, OrigenDato.simulado);
    expect(b.origen, OrigenDato.simulado);
    expect(b.timestampMs, 1000 + 4000);
    // 36 km/h = 10 m/s → 40 m en 4 s
    expect(distanciaHaversineM(a, b), closeTo(40, 2));
  });

  test('es determinista', () {
    SimuladorUnidad crear() => SimuladorUnidad(trazado: trazado, velocidadKmh: 30, intervaloS: 3, bucle: true, tiempoInicialMs: 0);
    final x = crear();
    final y = crear();
    for (var i = 0; i < 10; i++) {
      expect(x.avanzar().latitud, y.avanzar().latitud);
    }
  });

  test('sin bucle termina detenido; con bucle vuelve a empezar', () {
    final sin = SimuladorUnidad(trazado: trazado, velocidadKmh: 200, intervaloS: 60, bucle: false, tiempoInicialMs: 0);
    for (var i = 0; i < 20; i++) {
      sin.avanzar();
    }
    expect(sin.terminado, isTrue);
    expect(sin.actual().velocidadKmh, 0);

    final con = SimuladorUnidad(trazado: trazado, velocidadKmh: 200, intervaloS: 60, bucle: true, tiempoInicialMs: 0);
    for (var i = 0; i < 20; i++) {
      con.avanzar();
    }
    expect(con.terminado, isFalse);
  });

  test('parámetros inválidos', () {
    expect(() => SimuladorUnidad(trazado: const [Coordenada(20.3, -99.9)], velocidadKmh: 30, intervaloS: 3, bucle: true, tiempoInicialMs: 0), throwsArgumentError);
    expect(() => SimuladorUnidad(trazado: trazado, velocidadKmh: 0, intervaloS: 3, bucle: true, tiempoInicialMs: 0), throwsArgumentError);
  });
}
