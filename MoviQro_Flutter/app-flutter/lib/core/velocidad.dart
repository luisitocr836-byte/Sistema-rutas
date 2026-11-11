import 'tipos.dart';

class ConfigVelocidad {
  /// Por debajo de este valor (km/h) la unidad se considera detenida.
  final double umbralDetenidaKmh;

  /// Precisión GPS máxima aceptable (m) para confiar en la velocidad.
  final double precisionMaximaM;

  /// Edad máxima (ms) de un registro para considerarlo vigente.
  final int edadMaximaMs;

  /// Velocidad máxima verosímil (km/h) para un autobús urbano; mayores se descartan.
  final double velocidadMaximaKmh;

  /// Factor del suavizado exponencial (0..1). Mayor = reacciona más rápido.
  final double alfaSuavizado;

  const ConfigVelocidad({
    this.umbralDetenidaKmh = 2,
    this.precisionMaximaM = 50,
    this.edadMaximaMs = 60000,
    this.velocidadMaximaKmh = 110,
    this.alfaSuavizado = 0.4,
  });
}

const ConfigVelocidad configVelocidadPorDefecto = ConfigVelocidad();

/// ¿El registro es demasiado antiguo para usarse en un ETA?
bool esRegistroAntiguo(
  LecturaGps lectura,
  int ahoraMs, [
  ConfigVelocidad config = configVelocidadPorDefecto,
]) =>
    ahoraMs - lectura.timestampMs > config.edadMaximaMs;

/// Una velocidad es "confiable" si existe, es verosímil y la precisión GPS es buena.
bool velocidadEsConfiable(
  LecturaGps lectura, [
  ConfigVelocidad config = configVelocidadPorDefecto,
]) {
  final v = lectura.velocidadKmh;
  if (v == null || !v.isFinite || v < 0 || v > config.velocidadMaximaKmh) return false;
  final p = lectura.precisionM;
  if (p != null && p > config.precisionMaximaM) return false;
  return true;
}

bool estaDetenida(double? velocidadKmh, [ConfigVelocidad config = configVelocidadPorDefecto]) =>
    velocidadKmh != null && velocidadKmh < config.umbralDetenidaKmh;

/// Suavizado exponencial (EMA) sobre las lecturas cuya velocidad sea confiable.
/// [lecturas] debe estar en orden cronológico ascendente. Devuelve null si ninguna es utilizable.
double? suavizarVelocidadKmh(
  List<LecturaGps> lecturas, [
  ConfigVelocidad config = configVelocidadPorDefecto,
]) {
  double? ema;
  for (final l in lecturas) {
    if (!velocidadEsConfiable(l, config)) continue;
    final v = l.velocidadKmh!;
    ema = ema == null ? v : config.alfaSuavizado * v + (1 - config.alfaSuavizado) * ema;
  }
  return ema;
}

/// Clasificación orientativa de la condición de tráfico a partir de la relación entre la velocidad
/// suavizada y una velocidad de referencia. Es una heurística de presentación, NO una medición de tráfico.
CondicionTrafico clasificarCondicionTrafico(double? velocidadSuavizadaKmh, double velocidadReferenciaKmh) {
  if (velocidadSuavizadaKmh == null || velocidadReferenciaKmh <= 0) return CondicionTrafico.desconocido;
  final razon = velocidadSuavizadaKmh / velocidadReferenciaKmh;
  if (razon >= 0.75) return CondicionTrafico.fluido;
  if (razon >= 0.4) return CondicionTrafico.moderado;
  return CondicionTrafico.denso;
}
