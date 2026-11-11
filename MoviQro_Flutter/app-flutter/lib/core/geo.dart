import 'dart:math' as math;

import 'tipos.dart';

const double _radioTierraM = 6371008.8;

/// Límites aproximados del área de operación (San Juan del Río, Qro.) con margen amplio.
class LimitesRegion {
  static const double latMin = 20.2;
  static const double latMax = 20.6;
  static const double lonMin = -100.2;
  static const double lonMax = -99.8;
}

class ResultadoValidacion {
  final bool valido;
  final String? motivo;
  const ResultadoValidacion(this.valido, [this.motivo]);
}

/// Valida un par (latitud, longitud) en WGS84. Rechaza NaN/Infinity, valores fuera de rango y el
/// punto (0,0), que es el valor típico de un GPS sin posición fija.
ResultadoValidacion validarCoordenadas(double? latitud, double? longitud) {
  if (latitud == null || longitud == null) {
    return const ResultadoValidacion(false, 'Latitud y longitud deben ser números.');
  }
  if (!latitud.isFinite || !longitud.isFinite) {
    return const ResultadoValidacion(false, 'Latitud y longitud deben ser finitas.');
  }
  if (latitud < -90 || latitud > 90) {
    return const ResultadoValidacion(false, 'La latitud debe estar entre -90 y 90.');
  }
  if (longitud < -180 || longitud > 180) {
    return const ResultadoValidacion(false, 'La longitud debe estar entre -180 y 180.');
  }
  if (latitud == 0 && longitud == 0) {
    return const ResultadoValidacion(false, 'Coordenada (0,0): probable GPS sin posición.');
  }
  return const ResultadoValidacion(true);
}

bool estaEnRegionOperacion(Coordenada c) =>
    c.latitud >= LimitesRegion.latMin &&
    c.latitud <= LimitesRegion.latMax &&
    c.longitud >= LimitesRegion.lonMin &&
    c.longitud <= LimitesRegion.lonMax;

/// Km/h → m/s
double kmhAMs(double kmh) => kmh / 3.6;

/// m/s → km/h
double msAKmh(double ms) => ms * 3.6;

/// Convierte la velocidad que entrega el GPS del dispositivo (m/s; puede ser null, negativa o NaN
/// cuando no es válida) a km/h. Devuelve null si el dato no es utilizable.
double? velocidadDispositivoAKmh(double? velocidadMs) {
  if (velocidadMs == null) return null;
  if (!velocidadMs.isFinite || velocidadMs < 0) return null;
  return msAKmh(velocidadMs);
}

double _aRad(double grados) => grados * math.pi / 180;

/// Distancia en línea recta (haversine) en metros. Solo referencia; NO es distancia vial.
double distanciaHaversineM(Coordenada a, Coordenada b) {
  final dLat = _aRad(b.latitud - a.latitud);
  final dLon = _aRad(b.longitud - a.longitud);
  final lat1 = _aRad(a.latitud);
  final lat2 = _aRad(b.latitud);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  return 2 * _radioTierraM * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Longitud total de una polilínea en metros.
double longitudPolilineaM(List<Coordenada> linea) {
  var total = 0.0;
  for (var i = 1; i < linea.length; i++) {
    total += distanciaHaversineM(linea[i - 1], linea[i]);
  }
  return total;
}

class ProyeccionEnRuta {
  /// Distancia acumulada desde el inicio de la ruta hasta el punto proyectado (m).
  final double distanciaAlolargoM;

  /// Distancia perpendicular del punto original a la ruta (m).
  final double distanciaALineaM;

  /// Índice del segmento sobre el que se proyectó.
  final int indiceSegmento;
  final Coordenada puntoProyectado;

  const ProyeccionEnRuta({
    required this.distanciaAlolargoM,
    required this.distanciaALineaM,
    required this.indiceSegmento,
    required this.puntoProyectado,
  });
}

/// Proyecta un punto sobre una polilínea con una aproximación plana local (equirectangular),
/// adecuada para distancias urbanas de unos pocos km. Equivale conceptualmente a
/// ST_LineLocatePoint(linea, punto) * ST_Length(linea).
ProyeccionEnRuta proyectarEnRuta(List<Coordenada> linea, Coordenada punto) {
  if (linea.length < 2) {
    throw ArgumentError('La ruta necesita al menos 2 vértices.');
  }
  final lat0 = _aRad(punto.latitud);
  final kx = math.cos(lat0) * ((math.pi / 180) * _radioTierraM);
  final ky = (math.pi / 180) * _radioTierraM;

  ProyeccionEnRuta? mejor;
  var acumulado = 0.0;

  for (var i = 1; i < linea.length; i++) {
    final a = linea[i - 1];
    final b = linea[i];
    final ax = (a.longitud - punto.longitud) * kx;
    final ay = (a.latitud - punto.latitud) * ky;
    final bx = (b.longitud - punto.longitud) * kx;
    final by = (b.latitud - punto.latitud) * ky;
    final dx = bx - ax;
    final dy = by - ay;
    final largo2 = dx * dx + dy * dy;
    var t = largo2 == 0 ? 0.0 : -(ax * dx + ay * dy) / largo2;
    t = math.max(0.0, math.min(1.0, t));
    final px = ax + t * dx;
    final py = ay + t * dy;
    final dist = math.sqrt(px * px + py * py);
    final largoSegmento = distanciaHaversineM(a, b);

    if (mejor == null || dist < mejor.distanciaALineaM) {
      mejor = ProyeccionEnRuta(
        distanciaAlolargoM: acumulado + t * largoSegmento,
        distanciaALineaM: dist,
        indiceSegmento: i - 1,
        puntoProyectado: Coordenada(
          a.latitud + t * (b.latitud - a.latitud),
          a.longitud + t * (b.longitud - a.longitud),
        ),
      );
    }
    acumulado += largoSegmento;
  }
  return mejor!;
}

/// Punto situado a [distanciaM] metros del inicio, medido a lo largo de la polilínea.
Coordenada puntoAlolargoDeRuta(List<Coordenada> linea, double distanciaM) {
  if (linea.isEmpty) throw ArgumentError('Ruta vacía.');
  if (linea.length == 1 || distanciaM <= 0) return linea[0];
  var restante = distanciaM;
  for (var i = 1; i < linea.length; i++) {
    final tramo = distanciaHaversineM(linea[i - 1], linea[i]);
    if (restante <= tramo && tramo > 0) {
      final t = restante / tramo;
      return Coordenada(
        linea[i - 1].latitud + t * (linea[i].latitud - linea[i - 1].latitud),
        linea[i - 1].longitud + t * (linea[i].longitud - linea[i - 1].longitud),
      );
    }
    restante -= tramo;
  }
  return linea.last;
}
