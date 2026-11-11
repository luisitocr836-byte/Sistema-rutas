import 'package:flutter_test/flutter_test.dart';
import 'package:moviqro/core/core.dart';
import 'package:moviqro/datos/rutas_locales.dart';

void main() {
  final r = rutasLocales.first;
  final trazado = r.ruta.trazado;
  final paradas = r.paradas;
  double pos(Parada p) => proyectarEnRuta(trazado, p).distanciaAlolargoM;

  test('al inicio de la ruta la siguiente parada es la primera', () {
    final s = seleccionarSiguienteParada(trazado, paradas, trazado.first);
    expect(s, isNotNull);
    expect(s!.parada.ordenSecuencia, 1);
  });

  test('entre la parada 2 y la 3 la siguiente es la 3', () {
    final medio = (pos(paradas[1]) + pos(paradas[2])) / 2;
    final punto = puntoAlolargoDeRuta(trazado, medio);
    final s = seleccionarSiguienteParada(trazado, paradas, punto);
    expect(s!.parada.ordenSecuencia, 3);
    expect(s.distanciaPorRutaM, closeTo((pos(paradas[2]) - pos(paradas[1])) / 2, 5));
  });

  test('en la última parada el objetivo está a ~0 m', () {
    final s = seleccionarSiguienteParada(trazado, paradas, paradas.last);
    expect(s!.parada.ordenSecuencia, paradas.last.ordenSecuencia);
    expect(s.distanciaPorRutaM, lessThan(1));
  });

  test('sin trazado o sin paradas devuelve null', () {
    expect(seleccionarSiguienteParada(const [], paradas, trazado.first), isNull);
    expect(seleccionarSiguienteParada(trazado, const [], trazado.first), isNull);
  });
}
