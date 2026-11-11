import '../config/entorno.dart';
import '../core/core.dart';

String formatearMinutos(double min) {
  if (!min.isFinite || min < 0) return '—';
  if (min < 1) return '< 1 min';
  if (min < 60) return '${min.round()} min';
  final h = (min / 60).floor();
  final m = (min % 60).round();
  return m == 0 ? '$h h' : '$h h $m min';
}

String formatearDistancia(double m) {
  if (!m.isFinite || m < 0) return '—';
  return m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
}

String formatearKmh(double? v) => (v == null || !v.isFinite) ? 'Sin dato' : '${v.round()} km/h';

int? segundosDesde(String? iso, int ahoraMs) {
  if (iso == null) return null;
  final t = DateTime.tryParse(iso);
  if (t == null) return null;
  final diff = ((ahoraMs - t.millisecondsSinceEpoch) / 1000).round();
  return diff < 0 ? 0 : diff;
}

String describirEdad(int? seg) {
  if (seg == null) return 'sin registro';
  if (seg < 5) return 'ahora mismo';
  if (seg < 60) return 'hace $seg s';
  if (seg < 3600) return 'hace ${seg ~/ 60} min';
  return 'hace ${seg ~/ 3600} h';
}

enum EstadoUnidad { sinDatos, sinSenal, detenida, enMovimiento }

EstadoUnidad estadoDeUnidad(Unidad? u, int ahoraMs) {
  if (u == null || !u.tienePosicion) return EstadoUnidad.sinDatos;
  final edad = segundosDesde(u.ultimaActualizacion, ahoraMs);
  if (edad == null || edad > Parametros.edadMaximaPosicionS) return EstadoUnidad.sinSenal;
  final v = u.ultimaVelocidadKmh;
  return (v != null && v < 2) ? EstadoUnidad.detenida : EstadoUnidad.enMovimiento;
}

const Map<EstadoUnidad, String> textoEstadoUnidad = {
  EstadoUnidad.sinDatos: 'Sin datos GPS',
  EstadoUnidad.sinSenal: 'Sin señal GPS reciente',
  EstadoUnidad.detenida: 'Detenida',
  EstadoUnidad.enMovimiento: 'En movimiento',
};

bool estimacionVigente(Estimacion? e, int ahoraMs) {
  if (e == null) return false;
  final edad = segundosDesde(e.fechaCalculo, ahoraMs);
  return edad != null && edad <= Parametros.edadMaximaEstimacionS;
}

const _acentos = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
};

/// Minúsculas y sin acentos, para búsquedas tolerantes.
String normalizarTexto(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    b.write(_acentos[c] ?? c);
  }
  return b.toString();
}

/// Mensaje comprensible para el usuario a partir de un error técnico.
String mensajeDeError(Object e) {
  final t = e.toString();
  if (RegExp(r'network|socket|failed host|timeout|internet|connection', caseSensitive: false).hasMatch(t)) {
    return 'No se pudo conectar con el servidor. Revisa tu conexión a internet e inténtalo de nuevo.';
  }
  if (RegExp(r'JWT|permission|denied|row-level|RLS', caseSensitive: false).hasMatch(t)) {
    return 'No tienes permiso para realizar esta acción.';
  }
  return 'Ocurrió un problema inesperado. Inténtalo de nuevo en unos momentos.';
}
