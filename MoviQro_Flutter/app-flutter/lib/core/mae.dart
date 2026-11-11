/// Métricas de error para la validación del ETA.
///
///   error absoluto = | ETA estimado − tiempo real observado |   (minutos)
///   error %        = error absoluto / tiempo real × 100
///   MAE            = promedio de los errores absolutos de las observaciones válidas
///
/// Una observación es válida si ambos tiempos son finitos y el tiempo real es > 0.
/// Las estimaciones sin tiempo real observado NO entran al MAE.
library;

class ObservacionEta {
  final double? etaEstimadoMin;
  final double? tiempoRealMin;
  const ObservacionEta(this.etaEstimadoMin, this.tiempoRealMin);
}

bool esObservacionValida(ObservacionEta o) {
  final e = o.etaEstimadoMin;
  final r = o.tiempoRealMin;
  return e != null && r != null && e.isFinite && r.isFinite && e >= 0 && r > 0;
}

double errorAbsolutoMin(double etaEstimadoMin, double tiempoRealMin) =>
    (etaEstimadoMin - tiempoRealMin).abs();

double errorPorcentual(double etaEstimadoMin, double tiempoRealMin) {
  if (tiempoRealMin <= 0) throw ArgumentError('El tiempo real debe ser mayor que cero.');
  return errorAbsolutoMin(etaEstimadoMin, tiempoRealMin) / tiempoRealMin * 100;
}

class ResumenError {
  /// Número de observaciones válidas utilizadas.
  final int n;

  /// Número de observaciones descartadas por datos faltantes o inválidos.
  final int descartadas;

  /// Error Absoluto Medio en minutos; null si n = 0.
  final double? maeMin;

  /// Error porcentual medio (MAPE); null si n = 0.
  final double? mapePct;

  /// Error absoluto máximo; null si n = 0.
  final double? maxErrorMin;

  const ResumenError({
    required this.n,
    required this.descartadas,
    required this.maeMin,
    required this.mapePct,
    required this.maxErrorMin,
  });
}

ResumenError calcularMae(List<ObservacionEta> observaciones) {
  final validas = observaciones.where(esObservacionValida).toList();
  final descartadas = observaciones.length - validas.length;
  if (validas.isEmpty) {
    return ResumenError(n: 0, descartadas: descartadas, maeMin: null, mapePct: null, maxErrorMin: null);
  }
  final errores = [for (final o in validas) errorAbsolutoMin(o.etaEstimadoMin!, o.tiempoRealMin!)];
  final porcentuales = [for (final o in validas) errorPorcentual(o.etaEstimadoMin!, o.tiempoRealMin!)];
  double suma(List<double> xs) => xs.fold(0.0, (a, b) => a + b);
  var maximo = errores.first;
  for (final e in errores) {
    if (e > maximo) maximo = e;
  }
  return ResumenError(
    n: validas.length,
    descartadas: descartadas,
    maeMin: suma(errores) / errores.length,
    mapePct: suma(porcentuales) / porcentuales.length,
    maxErrorMin: maximo,
  );
}
