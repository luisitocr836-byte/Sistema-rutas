import 'package:flutter_test/flutter_test.dart';
import 'package:moviqro/core/core.dart';

LecturaGps _l(double? v, {double? precision = 5, int t = 0}) => LecturaGps(
      latitud: 20.38,
      longitud: -99.99,
      velocidadKmh: v,
      precisionM: precision,
      timestampMs: t,
      origen: OrigenDato.real,
    );

void main() {
  test('velocidad confiable: existe, verosímil y buena precisión', () {
    expect(velocidadEsConfiable(_l(30)), isTrue);
    expect(velocidadEsConfiable(_l(null)), isFalse);
    expect(velocidadEsConfiable(_l(-3)), isFalse);
    expect(velocidadEsConfiable(_l(200)), isFalse);
    expect(velocidadEsConfiable(_l(30, precision: 80)), isFalse);
    expect(velocidadEsConfiable(_l(30, precision: null)), isTrue);
  });

  test('detenida por debajo del umbral', () {
    expect(estaDetenida(1), isTrue);
    expect(estaDetenida(2), isFalse);
    expect(estaDetenida(null), isFalse);
  });

  test('registro antiguo', () {
    expect(esRegistroAntiguo(_l(10, t: 0), 60000), isFalse);
    expect(esRegistroAntiguo(_l(10, t: 0), 60001), isTrue);
  });

  test('suavizado exponencial ignora lecturas no confiables', () {
    final v = suavizarVelocidadKmh([_l(10), _l(null), _l(20)]);
    expect(v, closeTo(0.4 * 20 + 0.6 * 10, 1e-9));
    expect(suavizarVelocidadKmh([_l(null)]), isNull);
    expect(suavizarVelocidadKmh([]), isNull);
  });

  test('clasificación de tráfico es orientativa', () {
    expect(clasificarCondicionTrafico(null, 30), CondicionTrafico.desconocido);
    expect(clasificarCondicionTrafico(30, 30), CondicionTrafico.fluido);
    expect(clasificarCondicionTrafico(15, 30), CondicionTrafico.moderado);
    expect(clasificarCondicionTrafico(5, 30), CondicionTrafico.denso);
  });
}
