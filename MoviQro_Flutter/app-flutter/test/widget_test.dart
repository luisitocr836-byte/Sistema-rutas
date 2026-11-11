import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviqro/config/tema.dart';
import 'package:moviqro/utilidades/formato.dart';
import 'package:moviqro/widgets/comunes.dart';

void main() {
  testWidgets('InsigniaDato muestra la etiqueta Demostración', (t) async {
    await t.pumpWidget(MaterialApp(theme: temaMoviqro(), home: const Scaffold(body: InsigniaDato(TipoDato.demostracion))));
    expect(find.text('Demostración'), findsOneWidget);
  });

  test('formateo de minutos y distancias', () {
    expect(formatearMinutos(0.4), '< 1 min');
    expect(formatearMinutos(5.2), '5 min');
    expect(formatearMinutos(65), '1 h 5 min');
    expect(formatearMinutos(double.nan), '—');
    expect(formatearDistancia(450), '450 m');
    expect(formatearDistancia(1500), '1.5 km');
  });

  test('normalizarTexto quita acentos y mayúsculas', () {
    expect(normalizarTexto('Río Moctezuma'), 'rio moctezuma');
  });

  test('colorDeHex tolera valores inválidos', () {
    expect(colorDeHex('#1687ff'), const Color(0xFF1687FF));
    expect(colorDeHex(null), Colores.azul);
    expect(colorDeHex('zzz'), Colores.azul);
  });
}
