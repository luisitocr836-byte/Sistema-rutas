import 'package:flutter_test/flutter_test.dart';
import 'package:moviqro/core/core.dart';
import 'package:moviqro/datos/rutas_locales.dart';

class _ProveedorFijo implements ProveedorRuteo {
  final double distanciaM;
  final double duracionS;
  _ProveedorFijo(this.distanciaM, this.duracionS);
  @override
  String get nombre => 'fijo';
  @override
  Future<RespuestaRuteo> obtenerRuta(Coordenada origen, Coordenada destino) async =>
      RespuestaRuteo(distanciaM: distanciaM, duracionS: duracionS, fuente: FuenteCalculo.osrm);
}

class _ProveedorQueFalla implements ProveedorRuteo {
  @override
  String get nombre => 'falla';
  @override
  Future<RespuestaRuteo> obtenerRuta(Coordenada origen, Coordenada destino) async => throw Exception('sin red');
}

const _ahora = 1000000;

List<LecturaGps> _lecturas(Coordenada c, double? v, {int edadMs = 0, OrigenDato origen = OrigenDato.real}) => [
      for (var i = 0; i < 3; i++)
        LecturaGps(
          latitud: c.latitud,
          longitud: c.longitud,
          velocidadKmh: v,
          precisionM: 5,
          timestampMs: _ahora - edadMs - (2 - i) * 1000,
          origen: origen,
        ),
    ];

void main() {
  final r = rutasLocales.first;
  final trazado = r.ruta.trazado;
  final paradas = r.paradas;
  // Punto a medio camino entre la parada 1 y la 2.
  final medio = puntoAlolargoDeRuta(
    trazado,
    (proyectarEnRuta(trazado, paradas[0]).distanciaAlolargoM + proyectarEnRuta(trazado, paradas[1]).distanciaAlolargoM) / 2,
  );

  Future<ResultadoEta> calc(List<LecturaGps> l, ProveedorRuteo? p) =>
      calcularEta(lecturas: l, trazado: trazado, paradas: paradas, proveedor: p, ahoraMs: _ahora);

  test('sin lecturas → sin_datos_gps (no inventa ETA)', () async {
    final e = await calc(const [], null);
    expect(e.estado, EstadoEta.sinDatosGps);
    expect(e.etaMin, isNull);
  });

  test('coordenada inválida → estado explícito', () async {
    final e = await calc(_lecturas(const Coordenada(0, 0), 20), null);
    expect(e.estado, EstadoEta.coordenadaInvalida);
  });

  test('registro antiguo → no calcula', () async {
    final e = await calc(_lecturas(medio, 20, edadMs: 120000), null);
    expect(e.estado, EstadoEta.registroAntiguo);
    expect(e.etaMin, isNull);
  });

  test('sin trazado → sin_ruta', () async {
    final e = await calcularEta(lecturas: _lecturas(medio, 20), trazado: const [], paradas: paradas, proveedor: null, ahoraMs: _ahora);
    expect(e.estado, EstadoEta.sinRuta);
  });

  test('respaldo por trazado: distancia ÷ velocidad', () async {
    final e = await calc(_lecturas(medio, 30), null);
    expect(e.estado, EstadoEta.ok);
    expect(e.fuenteCalculo, FuenteCalculo.respaldoRuta);
    expect(e.etaMin, closeTo(e.distanciaRestanteM! / 1000 / 30 * 60, 1e-9));
    expect(e.paradaObjetivo!.ordenSecuencia, 2);
  });

  test('respaldo sin velocidad confiable usa 15 km/h y lo advierte', () async {
    final e = await calc(_lecturas(medio, null), null);
    expect(e.etaMin, closeTo(e.distanciaRestanteM! / 1000 / 15 * 60, 1e-9));
    expect(e.advertencias.any((a) => a.contains('15')), isTrue);
  });

  test('mezcla proveedor + vehículo con peso 0.6', () async {
    final e = await calc(_lecturas(medio, 30), _ProveedorFijo(600, 120));
    expect(e.fuenteCalculo, FuenteCalculo.osrm);
    const vial = 2.0; // 120 s
    final vehiculo = 600 / 1000 / 30 * 60;
    expect(e.etaMin, closeTo(0.6 * vial + 0.4 * vehiculo, 1e-9));
  });

  test('unidad detenida: solo duración vial', () async {
    final e = await calc(_lecturas(medio, 0), _ProveedorFijo(600, 600));
    expect(e.unidadDetenida, isTrue);
    expect(e.etaMin, closeTo(10, 1e-9));
  });

  test('si el proveedor falla se usa el respaldo y se declara', () async {
    final e = await calc(_lecturas(medio, 30), _ProveedorQueFalla());
    expect(e.estado, EstadoEta.ok);
    expect(e.fuenteCalculo, FuenteCalculo.respaldoRuta);
    expect(e.advertencias.any((a) => a.contains('Proveedor')), isTrue);
  });

  test('lecturas simuladas se marcan como simuladas', () async {
    final e = await calc(_lecturas(medio, 30, origen: OrigenDato.simulado), null);
    expect(e.esSimulado, isTrue);
  });

  test('llegada dentro del radio', () {
    expect(haLlegadoAParada(paradas[1], paradas[1], 40), isTrue);
    expect(haLlegadoAParada(paradas[0], paradas[3], 40), isFalse);
  });

  test('el cálculo es determinista (sin aleatoriedad)', () async {
    final a = await calc(_lecturas(medio, 30), null);
    final b = await calc(_lecturas(medio, 30), null);
    expect(a.etaMin, b.etaMin);
  });
}
