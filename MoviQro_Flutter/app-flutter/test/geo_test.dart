import 'package:flutter_test/flutter_test.dart';
import 'package:moviqro/core/core.dart';

void main() {
  group('validarCoordenadas', () {
    test('acepta una coordenada de San Juan del Río', () {
      expect(validarCoordenadas(20.3889, -99.9961).valido, isTrue);
    });
    test('rechaza null, NaN e infinito', () {
      expect(validarCoordenadas(null, -99.9).valido, isFalse);
      expect(validarCoordenadas(double.nan, -99.9).valido, isFalse);
      expect(validarCoordenadas(20.3, double.infinity).valido, isFalse);
    });
    test('rechaza latitud o longitud fuera de rango', () {
      expect(validarCoordenadas(91, -99.9).valido, isFalse);
      expect(validarCoordenadas(-99.99, 20.3).valido, isFalse);
      expect(validarCoordenadas(20.3, 181).valido, isFalse);
    });
    test('rechaza (0,0) por GPS sin posición', () {
      final r = validarCoordenadas(0, 0);
      expect(r.valido, isFalse);
      expect(r.motivo, contains('(0,0)'));
    });
    test('región de operación', () {
      expect(estaEnRegionOperacion(const Coordenada(20.39, -99.99)), isTrue);
      expect(estaEnRegionOperacion(const Coordenada(19.43, -99.13)), isFalse);
    });
  });

  group('conversión de velocidad', () {
    test('km/h ↔ m/s', () {
      expect(kmhAMs(36), closeTo(10, 1e-9));
      expect(msAKmh(10), closeTo(36, 1e-9));
    });
    test('velocidad del dispositivo: null, negativa o NaN → null', () {
      expect(velocidadDispositivoAKmh(null), isNull);
      expect(velocidadDispositivoAKmh(-1), isNull);
      expect(velocidadDispositivoAKmh(double.nan), isNull);
      expect(velocidadDispositivoAKmh(0), 0);
      expect(velocidadDispositivoAKmh(5), closeTo(18, 1e-9));
    });
  });

  group('distancias', () {
    test('1 grado de latitud ≈ 111.19 km', () {
      final d = distanciaHaversineM(const Coordenada(20, -99), const Coordenada(21, -99));
      expect(d, closeTo(111195, 50));
    });
    test('misma coordenada = 0', () {
      expect(distanciaHaversineM(const Coordenada(20.3, -99.9), const Coordenada(20.3, -99.9)), 0);
    });
    test('longitud de polilínea = suma de tramos', () {
      const a = Coordenada(20.38, -99.99);
      const b = Coordenada(20.39, -99.99);
      const c = Coordenada(20.39, -99.98);
      expect(longitudPolilineaM([a, b, c]), closeTo(distanciaHaversineM(a, b) + distanciaHaversineM(b, c), 1e-6));
      expect(longitudPolilineaM([a]), 0);
    });
    test('proyección sobre la ruta y punto a lo largo', () {
      const linea = [Coordenada(20.38, -99.99), Coordenada(20.39, -99.99)];
      final largo = longitudPolilineaM(linea);
      final mitad = puntoAlolargoDeRuta(linea, largo / 2);
      final p = proyectarEnRuta(linea, mitad);
      expect(p.distanciaAlolargoM, closeTo(largo / 2, 1));
      expect(p.distanciaALineaM, lessThan(1));
    });
    test('proyectar exige al menos 2 vértices', () {
      expect(() => proyectarEnRuta(const [Coordenada(20.3, -99.9)], const Coordenada(20.3, -99.9)), throwsArgumentError);
    });
  });
}
