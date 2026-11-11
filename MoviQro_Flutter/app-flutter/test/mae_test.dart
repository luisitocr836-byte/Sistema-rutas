import 'package:flutter_test/flutter_test.dart';
import 'package:moviqro/core/core.dart';

void main() {
  test('error absoluto y porcentual', () {
    expect(errorAbsolutoMin(5, 4), 1);
    expect(errorAbsolutoMin(3, 4), 1);
    expect(errorPorcentual(5, 4), closeTo(25, 1e-9));
    expect(() => errorPorcentual(5, 0), throwsArgumentError);
  });

  test('MAE con observaciones válidas (ejemplo numérico)', () {
    final r = calcularMae(const [ObservacionEta(5, 4), ObservacionEta(3, 4), ObservacionEta(10, 8)]);
    expect(r.n, 3);
    expect(r.descartadas, 0);
    expect(r.maeMin, closeTo((1 + 1 + 2) / 3, 1e-9));
    expect(r.maxErrorMin, 2);
    expect(r.mapePct, closeTo((25 + 25 + 25) / 3, 1e-9));
  });

  test('datos faltantes o inválidos se descartan y no entran al MAE', () {
    final r = calcularMae(const [
      ObservacionEta(5, null),
      ObservacionEta(null, 4),
      ObservacionEta(5, 0),
      ObservacionEta(-1, 4),
      ObservacionEta(double.nan, 4),
      ObservacionEta(6, 4),
    ]);
    expect(r.n, 1);
    expect(r.descartadas, 5);
    expect(r.maeMin, 2);
  });

  test('sin observaciones: MAE nulo, no 0', () {
    final r = calcularMae(const []);
    expect(r.n, 0);
    expect(r.maeMin, isNull);
    expect(r.mapePct, isNull);
    expect(r.maxErrorMin, isNull);
  });
}
