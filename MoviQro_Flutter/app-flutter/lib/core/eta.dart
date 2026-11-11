import 'geo.dart';
import 'siguiente_parada.dart';
import 'tipos.dart';
import 'velocidad.dart';

class ConfigEta {
  final ConfigVelocidad velocidad;

  /// Peso (0..1) de la duración vial del proveedor frente a la duración basada en la velocidad del
  /// vehículo cuando ambas existen. VALOR INICIAL SIN CALIBRAR: ajustar con el MAE de la validación de campo.
  final double pesoProveedor;

  /// Velocidad media (km/h) usada SOLO en el respaldo cuando no hay velocidad confiable. Supuesto sin calibrar.
  final double velocidadRespaldoKmh;

  /// Velocidad de referencia (km/h) para clasificar la condición de tráfico.
  final double velocidadReferenciaKmh;

  /// Margen en metros para considerar que la unidad llegó a la parada.
  final double radioLlegadaM;

  const ConfigEta({
    this.velocidad = configVelocidadPorDefecto,
    this.pesoProveedor = 0.6,
    this.velocidadRespaldoKmh = 15,
    this.velocidadReferenciaKmh = 30,
    this.radioLlegadaM = 40,
  });
}

enum EstadoEta { ok, sinDatosGps, coordenadaInvalida, registroAntiguo, sinRuta, sinParadaPendiente }

class ResultadoEta {
  final EstadoEta estado;
  final String mensaje;
  final Parada? paradaObjetivo;
  final double? etaMin;
  final double? distanciaRestanteM;
  final double? velocidadSuavizadaKmh;
  final CondicionTrafico? condicionTrafico;
  final FuenteCalculo? fuenteCalculo;
  final bool? unidadDetenida;

  /// true si la lectura base fue simulada (se debe etiquetar "Demostración").
  final bool? esSimulado;
  final List<String> advertencias;
  final int? latenciaCalculoMs;

  const ResultadoEta({
    required this.estado,
    required this.mensaje,
    this.paradaObjetivo,
    this.etaMin,
    this.distanciaRestanteM,
    this.velocidadSuavizadaKmh,
    this.condicionTrafico,
    this.fuenteCalculo,
    this.unidadDetenida,
    this.esSimulado,
    this.advertencias = const [],
    this.latenciaCalculoMs,
  });
}

double _segundosAMin(double s) => s / 60;

/// Motor de estimación ETA.
///
/// 1. Toma la última coordenada válida de la unidad.
/// 2. Descarta registros antiguos o inválidos (no inventa un ETA).
/// 3. Determina la siguiente parada relevante sobre el trazado.
/// 4. Consulta distancia y duración vial al proveedor (OSRM). Si falla o no hay, usa un respaldo
///    basado en la distancia por el trazado.
/// 5. Combina la duración vial con la velocidad suavizada cuando ésta es confiable y la unidad
///    está en movimiento. Si está detenida usa solo la duración vial.
///
/// No genera valores aleatorios. Si no hay datos suficientes devuelve un estado explícito.
Future<ResultadoEta> calcularEta({
  required List<LecturaGps> lecturas,
  required List<Coordenada> trazado,
  required List<Parada> paradas,
  required ProveedorRuteo? proveedor,
  required int ahoraMs,
  ConfigEta config = const ConfigEta(),
}) async {
  final t0 = DateTime.now().millisecondsSinceEpoch;
  final advertencias = <String>[];

  if (lecturas.isEmpty) {
    return ResultadoEta(estado: EstadoEta.sinDatosGps, mensaje: 'Aún no hay posiciones GPS de esta unidad.', advertencias: advertencias);
  }
  final ultima = lecturas.last;
  final valid = validarCoordenadas(ultima.latitud, ultima.longitud);
  if (!valid.valido) {
    return ResultadoEta(estado: EstadoEta.coordenadaInvalida, mensaje: valid.motivo ?? 'Coordenada inválida.', advertencias: advertencias);
  }
  if (esRegistroAntiguo(ultima, ahoraMs, config.velocidad)) {
    final seg = ((ahoraMs - ultima.timestampMs) / 1000).round();
    return ResultadoEta(
      estado: EstadoEta.registroAntiguo,
      mensaje: 'La última posición tiene $seg s de antigüedad; no se calcula ETA con datos viejos.',
      advertencias: advertencias,
    );
  }
  if (trazado.length < 2) {
    return ResultadoEta(estado: EstadoEta.sinRuta, mensaje: 'La ruta asignada no tiene trazado disponible.', advertencias: advertencias);
  }

  final siguiente = seleccionarSiguienteParada(trazado, paradas, ultima);
  if (siguiente == null) {
    return ResultadoEta(
      estado: EstadoEta.sinParadaPendiente,
      mensaje: 'No hay paradas pendientes (la unidad ya rebasó la última parada o no hay paradas).',
      advertencias: advertencias,
    );
  }

  final validas = lecturas.where((l) => validarCoordenadas(l.latitud, l.longitud).valido).toList();
  final velocidadSuavizada = suavizarVelocidadKmh(validas, config.velocidad);
  final detenida = estaDetenida(velocidadSuavizada, config.velocidad);
  final velConfiable = velocidadEsConfiable(ultima, config.velocidad) && velocidadSuavizada != null;

  var distanciaM = siguiente.distanciaPorRutaM;
  double? duracionVialMin;
  var fuente = FuenteCalculo.respaldoRuta;

  if (proveedor != null) {
    try {
      final r = await proveedor.obtenerRuta(ultima, siguiente.parada);
      distanciaM = r.distanciaM;
      duracionVialMin = _segundosAMin(r.duracionS);
      fuente = r.fuente;
    } catch (e) {
      advertencias.add('Proveedor de ruteo no disponible ($e); se usó el respaldo por trazado.');
    }
  } else {
    advertencias.add('No hay proveedor de ruteo configurado; se usó el respaldo por trazado.');
  }

  final double etaMin;
  final double? velParaTiempo =
      velocidadSuavizada != null && velocidadSuavizada >= config.velocidad.umbralDetenidaKmh ? velocidadSuavizada : null;

  if (duracionVialMin != null) {
    if (velConfiable && !detenida && velParaTiempo != null) {
      final duracionVehiculoMin = distanciaM / 1000 / velParaTiempo * 60;
      etaMin = config.pesoProveedor * duracionVialMin + (1 - config.pesoProveedor) * duracionVehiculoMin;
    } else {
      etaMin = duracionVialMin;
      if (detenida) {
        advertencias.add('La unidad está detenida; el ETA usa solo la duración vial y puede subestimar la espera.');
      }
    }
  } else {
    final double velKmh;
    if (velConfiable && velParaTiempo != null) {
      velKmh = velParaTiempo;
    } else {
      velKmh = config.velocidadRespaldoKmh;
      advertencias.add('Sin velocidad confiable: se asumió ${config.velocidadRespaldoKmh} km/h (supuesto configurable).');
    }
    etaMin = distanciaM / 1000 / velKmh * 60;
  }

  return ResultadoEta(
    estado: EstadoEta.ok,
    mensaje: 'ETA calculado.',
    paradaObjetivo: siguiente.parada,
    etaMin: etaMin,
    distanciaRestanteM: distanciaM,
    velocidadSuavizadaKmh: velocidadSuavizada,
    condicionTrafico: clasificarCondicionTrafico(velocidadSuavizada, config.velocidadReferenciaKmh),
    fuenteCalculo: fuente,
    unidadDetenida: detenida,
    esSimulado: ultima.origen == OrigenDato.simulado,
    advertencias: advertencias,
    latenciaCalculoMs: DateTime.now().millisecondsSinceEpoch - t0,
  );
}

/// ¿La unidad está dentro del radio de llegada de la parada? (línea recta, solo para detectar llegada)
bool haLlegadoAParada(Coordenada posicion, Coordenada parada, double radioM) =>
    distanciaHaversineM(posicion, parada) <= radioM;
