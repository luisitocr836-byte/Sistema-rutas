import 'package:flutter_test/flutter_test.dart';
import 'package:moviqro/core/core.dart';

void main() {
  test('LineString GeoJSON [lon,lat] → Coordenada(lat, lon)', () {
    final c = lineStringGeoJsonACoordenadas({
      'type': 'LineString',
      'coordinates': [
        [-99.99, 20.38],
        [-99.98, 20.39]
      ]
    });
    expect(c.first, const Coordenada(20.38, -99.99));
    expect(c.length, 2);
  });

  test('geometrías o vértices inválidos lanzan FormatException', () {
    expect(() => lineStringGeoJsonACoordenadas({'type': 'Point', 'coordinates': [1, 2]}), throwsFormatException);
    expect(
      () => lineStringGeoJsonACoordenadas({'type': 'LineString', 'coordinates': [[0, 0]]}),
      throwsFormatException,
    );
    expect(
      () => lineStringGeoJsonACoordenadas({'type': 'LineString', 'coordinates': [['a', 1]]}),
      throwsFormatException,
    );
  });
}
