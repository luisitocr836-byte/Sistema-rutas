import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moviqro/core/core.dart';

const _a = Coordenada(20.3889, -99.9961);
const _b = Coordenada(20.386, -99.986);

void main() {
  test('construye la URL con orden lon,lat y lee distancia y duración', () async {
    Uri? pedida;
    final cliente = MockClient((req) async {
      pedida = req.url;
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {'distance': 1234.5, 'duration': 180}
          ]
        }),
        200,
      );
    });
    final r = await ProveedorOsrm('https://osrm.ejemplo.test/', cliente: cliente).obtenerRuta(_a, _b);
    expect(r.distanciaM, 1234.5);
    expect(r.duracionS, 180);
    expect(r.fuente, FuenteCalculo.osrm);
    expect(pedida!.path, '/route/v1/driving/-99.9961,20.3889;-99.986,20.386');
  });

  test('HTTP de error, code distinto de Ok y valores inválidos lanzan', () async {
    Future<void> intentar(http.Response resp) =>
        ProveedorOsrm('https://osrm.ejemplo.test', cliente: MockClient((_) async => resp)).obtenerRuta(_a, _b);
    await expectLater(intentar(http.Response('x', 500)), throwsException);
    await expectLater(intentar(http.Response(jsonEncode({'code': 'NoRoute'}), 200)), throwsException);
    await expectLater(
      intentar(http.Response(jsonEncode({'code': 'Ok', 'routes': [{'distance': -1, 'duration': 3}]}), 200)),
      throwsException,
    );
  });

  test('URL base inválida', () {
    expect(() => ProveedorOsrm('osrm.ejemplo.test'), throwsArgumentError);
  });

  test('tiempo de espera agotado', () async {
    final cliente = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return http.Response('{}', 200);
    });
    final p = ProveedorOsrm('https://osrm.ejemplo.test', timeout: const Duration(milliseconds: 20), cliente: cliente);
    await expectLater(p.obtenerRuta(_a, _b), throwsException);
  });
}
