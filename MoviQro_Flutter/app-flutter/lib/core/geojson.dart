import 'geo.dart';
import 'tipos.dart';

/// Convierte una geometría GeoJSON LineString (columna `trazado_geojson` de la vista v_rutas)
/// a una lista de coordenadas. GeoJSON usa [longitud, latitud].
List<Coordenada> lineStringGeoJsonACoordenadas(Object? geojson) {
  if (geojson is! Map || geojson['type'] != 'LineString' || geojson['coordinates'] is! List) {
    throw const FormatException('Se esperaba una geometría GeoJSON LineString.');
  }
  final coords = geojson['coordinates'] as List;
  final resultado = <Coordenada>[];
  for (var i = 0; i < coords.length; i++) {
    final par = coords[i];
    if (par is! List || par.length < 2 || par[0] is! num || par[1] is! num) {
      throw FormatException('Vértice ${i + 1}: debe ser [longitud, latitud].');
    }
    final lon = (par[0] as num).toDouble();
    final lat = (par[1] as num).toDouble();
    final v = validarCoordenadas(lat, lon);
    if (!v.valido) throw FormatException('Vértice ${i + 1}: ${v.motivo}');
    resultado.add(Coordenada(lat, lon));
  }
  return resultado;
}
