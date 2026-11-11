import 'package:flutter_test/flutter_test.dart';
import 'package:moviqro/core/core.dart';

LecturaGps _l(int t, {double lat = 20.38, double lon = -99.99, double? v = 20}) => LecturaGps(
      latitud: lat,
      longitud: lon,
      velocidadKmh: v,
      precisionM: 5,
      timestampMs: t,
      origen: OrigenDato.real,
    );

void main() {
  test('el buffer conserva hasta 20 y descarta la más antigua', () {
    final b = BufferTelemetria();
    for (var i = 0; i < 25; i++) {
      b.agregar(_l(i));
    }
    expect(b.tamano, 20);
    expect(b.descartadas, 5);
    expect(b.instantanea().first.timestampMs, 5);
  });

  test('vaciar envía el lote y deja el buffer vacío', () async {
    final b = BufferTelemetria()..agregar(_l(1))..agregar(_l(2));
    var recibido = 0;
    final r = await b.vaciar((lote) async => recibido = lote.length);
    expect(r.enviadas, 2);
    expect(recibido, 2);
    expect(b.tamano, 0);
  });

  test('si el envío falla las lecturas se conservan', () async {
    final b = BufferTelemetria()..agregar(_l(1))..agregar(_l(2));
    final r = await b.vaciar((lote) async => throw Exception('sin red'));
    expect(r.enviadas, 0);
    expect(r.error, isNotNull);
    expect(b.tamano, 2);
  });

  test('fila de coordenadas_log y validaciones', () {
    final f = aFilaCoordenadasLog(7, _l(1700000000000, v: 31.256));
    expect(f['id_unidad'], 7);
    expect(f['velocidad_kmh'], 31.26);
    expect(f['origen_dato'], 'real');
    expect(f['fecha_hora'], '2023-11-14T22:13:20.000Z');
    expect(() => aFilaCoordenadasLog(0, _l(1)), throwsArgumentError);
    expect(() => aFilaCoordenadasLog(1, _l(1, lat: 0, lon: 0)), throwsArgumentError);
    expect(() => aFilaCoordenadasLog(1, _l(1, v: 500)), throwsArgumentError);
  });

  test('capacidad inválida', () {
    expect(() => BufferTelemetria(0), throwsArgumentError);
  });
}
