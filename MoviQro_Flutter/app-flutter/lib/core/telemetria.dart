import 'geo.dart';
import 'tipos.dart';

/// Buffer local de telemetría: ante pérdida de conectividad se conservan hasta 20 posiciones y se
/// transmiten en ráfaga al restablecerse. Si se llena se descarta la más antigua.
const int capacidadBufferPorDefecto = 20;

class ResultadoVaciado {
  final int enviadas;
  final String? error;
  const ResultadoVaciado(this.enviadas, [this.error]);
}

class BufferTelemetria {
  final int capacidad;
  List<LecturaGps> _cola = [];
  bool _vaciando = false;

  /// Lecturas descartadas por desbordamiento desde que se creó el buffer.
  int descartadas = 0;

  BufferTelemetria([this.capacidad = capacidadBufferPorDefecto]) {
    if (capacidad < 1) throw ArgumentError('La capacidad debe ser un entero >= 1.');
  }

  int get tamano => _cola.length;

  void agregar(LecturaGps lectura) {
    _cola.add(lectura);
    while (_cola.length > capacidad) {
      _cola.removeAt(0);
      descartadas++;
    }
  }

  /// Intenta enviar todo lo acumulado en una sola ráfaga. Si [enviar] lanza, las lecturas se
  /// conservan y se devuelve el error. Si ya hay un envío en curso no hace nada.
  Future<ResultadoVaciado> vaciar(Future<void> Function(List<LecturaGps> lote) enviar) async {
    if (_vaciando || _cola.isEmpty) return const ResultadoVaciado(0);
    _vaciando = true;
    final lote = _cola;
    _cola = [];
    try {
      await enviar(lote);
      return ResultadoVaciado(lote.length);
    } catch (e) {
      _cola = [...lote, ..._cola];
      while (_cola.length > capacidad) {
        _cola.removeAt(0);
        descartadas++;
      }
      return ResultadoVaciado(0, e.toString());
    } finally {
      _vaciando = false;
    }
  }

  List<LecturaGps> instantanea() => List.unmodifiable(_cola);
}

/// Convierte una lectura en la fila que se inserta en coordenadas_log. Lanza si es inválida.
Map<String, Object?> aFilaCoordenadasLog(int idUnidad, LecturaGps l) {
  if (idUnidad <= 0) throw ArgumentError('Identificador de unidad inválido.');
  final v = validarCoordenadas(l.latitud, l.longitud);
  if (!v.valido) throw ArgumentError(v.motivo);
  final vel = l.velocidadKmh;
  if (vel != null && (!vel.isFinite || vel < 0 || vel > 200)) {
    throw ArgumentError('Velocidad fuera de rango (0–200 km/h).');
  }
  final p = l.precisionM;
  return {
    'id_unidad': idUnidad,
    'latitud': l.latitud,
    'longitud': l.longitud,
    'velocidad_kmh': vel == null ? null : (vel * 100).round() / 100,
    'precision_gps_m': p != null && p.isFinite && p >= 0 ? p : null,
    'fecha_hora': DateTime.fromMillisecondsSinceEpoch(l.timestampMs, isUtc: true).toIso8601String(),
    'origen_dato': l.origen.db,
  };
}
