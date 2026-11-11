import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tipos.dart';

/// Proveedor OSRM (Open Source Routing Machine) vía API HTTP /route/v1.
///
/// ⚠ El servidor público https://router.project-osrm.org es solo de demostración. Para validación
/// real se recomienda una instancia propia. OSRM NO incorpora tráfico en vivo.
class ProveedorOsrm implements ProveedorRuteo {
  @override
  final String nombre = 'osrm';
  final String _baseUrl;
  final Duration timeout;
  final http.Client _cliente;

  ProveedorOsrm(String baseUrl, {this.timeout = const Duration(seconds: 4), http.Client? cliente})
      : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _cliente = cliente ?? http.Client() {
    if (!RegExp(r'^https?://').hasMatch(baseUrl)) {
      throw ArgumentError('La URL de OSRM debe iniciar con http:// o https://');
    }
  }

  @override
  Future<RespuestaRuteo> obtenerRuta(Coordenada origen, Coordenada destino) async {
    // OSRM espera lon,lat (mismo orden que PostGIS).
    final coords = '${origen.longitud},${origen.latitud};${destino.longitud},${destino.latitud}';
    final uri = Uri.parse('$_baseUrl/route/v1/driving/$coords?overview=false&alternatives=false&steps=false');
    final http.Response resp;
    try {
      resp = await _cliente.get(uri).timeout(timeout);
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado (${timeout.inMilliseconds} ms).');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('El proveedor respondió HTTP ${resp.statusCode}.');
    }
    final datos = jsonDecode(resp.body);
    if (datos is! Map<String, dynamic> || datos['code'] != 'Ok') {
      throw Exception('OSRM no devolvió ruta (code=${datos is Map ? datos['code'] : null}).');
    }
    final rutas = datos['routes'];
    if (rutas is! List || rutas.isEmpty || rutas.first is! Map) {
      throw Exception('OSRM no devolvió ruta (sin rutas).');
    }
    final distancia = (rutas.first as Map)['distance'];
    final duracion = (rutas.first as Map)['duration'];
    if (distancia is! num || duracion is! num || !distancia.isFinite || !duracion.isFinite || distancia < 0 || duracion < 0) {
      throw Exception('Respuesta de OSRM con distancia/duración inválidas.');
    }
    return RespuestaRuteo(
      distanciaM: distancia.toDouble(),
      duracionS: duracion.toDouble(),
      fuente: FuenteCalculo.osrm,
    );
  }
}
