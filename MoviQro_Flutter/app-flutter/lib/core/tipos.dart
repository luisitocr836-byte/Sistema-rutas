/// Tipos del núcleo de MoviQro (Dart puro: sin Flutter ni Supabase).
///
/// Convención espacial: en PostGIS el orden es (longitud, latitud). En el código de la app se usan
/// objetos con nombres explícitos (latitud, longitud) para evitar inversiones.
library;

class Coordenada {
  final double latitud;
  final double longitud;
  const Coordenada(this.latitud, this.longitud);

  @override
  bool operator ==(Object other) =>
      other is Coordenada && other.latitud == latitud && other.longitud == longitud;

  @override
  int get hashCode => Object.hash(latitud, longitud);

  @override
  String toString() => 'Coordenada($latitud, $longitud)';
}

/// Procedencia del dato: permite diferenciar datos reales de simulados.
enum OrigenDato {
  real('real'),
  simulado('simulado');

  final String db;
  const OrigenDato(this.db);

  static OrigenDato? desdeDb(String? s) {
    for (final v in OrigenDato.values) {
      if (v.db == s) return v;
    }
    return null;
  }
}

/// Procedencia de la geometría/catálogo (rutas, paradas, unidades).
enum FuenteDatos {
  oficial('oficial'),
  levantamientoEquipo('levantamiento_equipo'),
  demostracion('demostracion');

  final String db;
  const FuenteDatos(this.db);

  static FuenteDatos desdeDb(String? s) {
    for (final v in FuenteDatos.values) {
      if (v.db == s) return v;
    }
    // Ante un valor desconocido se asume lo más prudente: no presentarlo como oficial.
    return FuenteDatos.demostracion;
  }
}

enum CondicionTrafico {
  fluido('fluido'),
  moderado('moderado'),
  denso('denso'),
  desconocido('desconocido');

  final String db;
  const CondicionTrafico(this.db);

  static CondicionTrafico desdeDb(String? s) {
    for (final v in CondicionTrafico.values) {
      if (v.db == s) return v;
    }
    return CondicionTrafico.desconocido;
  }
}

enum FuenteCalculo {
  osrm('osrm'),
  googleDistanceMatrix('google_distance_matrix'),
  respaldoRuta('respaldo_ruta');

  final String db;
  const FuenteCalculo(this.db);

  static FuenteCalculo desdeDb(String? s) {
    for (final v in FuenteCalculo.values) {
      if (v.db == s) return v;
    }
    return FuenteCalculo.respaldoRuta;
  }
}

class LecturaGps extends Coordenada {
  /// Velocidad en km/h (ya convertida). null si el dispositivo no la reporta.
  final double? velocidadKmh;

  /// Precisión horizontal en metros, si está disponible.
  final double? precisionM;

  /// Instante de la medición (milisegundos Unix).
  final int timestampMs;
  final OrigenDato origen;

  const LecturaGps({
    required double latitud,
    required double longitud,
    required this.velocidadKmh,
    required this.precisionM,
    required this.timestampMs,
    required this.origen,
  }) : super(latitud, longitud);

  LecturaGps copiarCon({int? timestampMs}) => LecturaGps(
        latitud: latitud,
        longitud: longitud,
        velocidadKmh: velocidadKmh,
        precisionM: precisionM,
        timestampMs: timestampMs ?? this.timestampMs,
        origen: origen,
      );
}

class Parada extends Coordenada {
  final int idParada;
  final int idRuta;
  final String nombre;
  final String? referenciaVial;
  final int ordenSecuencia;
  final bool esNodoTransferencia;

  const Parada({
    required this.idParada,
    required this.idRuta,
    required this.nombre,
    this.referenciaVial,
    required this.ordenSecuencia,
    this.esNodoTransferencia = false,
    required double latitud,
    required double longitud,
  }) : super(latitud, longitud);
}

class Ruta {
  final int idRuta;
  final String numeroRuta;
  final String nombre;
  final String origen;
  final String destino;
  final double? distanciaKm;
  final String? colorHex;
  final String? horarioInicio;
  final String? horarioFin;
  final int? frecuenciaPromedioMin;
  final bool activa;

  /// Polilínea del trazado en orden de recorrido.
  final List<Coordenada> trazado;
  final FuenteDatos fuenteDatos;

  const Ruta({
    required this.idRuta,
    required this.numeroRuta,
    required this.nombre,
    required this.origen,
    required this.destino,
    this.distanciaKm,
    this.colorHex,
    this.horarioInicio,
    this.horarioFin,
    this.frecuenciaPromedioMin,
    this.activa = true,
    required this.trazado,
    required this.fuenteDatos,
  });
}

class RutaConParadas {
  final Ruta ruta;
  final List<Parada> paradas;
  const RutaConParadas({required this.ruta, required this.paradas});
}

class Unidad {
  final int idUnidad;
  final int? idRuta;
  final String numeroEconomico;
  final String estadoOperativo;
  final double? ultimaLatitud;
  final double? ultimaLongitud;
  final double? ultimaVelocidadKmh;

  /// ISO 8601
  final String? ultimaActualizacion;
  final OrigenDato? ultimoOrigenDato;

  const Unidad({
    required this.idUnidad,
    required this.idRuta,
    required this.numeroEconomico,
    required this.estadoOperativo,
    this.ultimaLatitud,
    this.ultimaLongitud,
    this.ultimaVelocidadKmh,
    this.ultimaActualizacion,
    this.ultimoOrigenDato,
  });

  bool get tienePosicion => ultimaLatitud != null && ultimaLongitud != null;

  Unidad conPosicion({
    required double latitud,
    required double longitud,
    required double? velocidadKmh,
    required String actualizacionIso,
    required OrigenDato origen,
  }) =>
      Unidad(
        idUnidad: idUnidad,
        idRuta: idRuta,
        numeroEconomico: numeroEconomico,
        estadoOperativo: estadoOperativo,
        ultimaLatitud: latitud,
        ultimaLongitud: longitud,
        ultimaVelocidadKmh: velocidadKmh,
        ultimaActualizacion: actualizacionIso,
        ultimoOrigenDato: origen,
      );
}

class Estimacion {
  final int idEstimacion;
  final int idUnidad;
  final int idParadaObjetivo;
  final double distanciaRestanteM;
  final double? velocidadSuavizadaKmh;
  final CondicionTrafico condicionTrafico;
  final FuenteCalculo fuenteCalculo;
  final double etaEstimadoMin;
  final double? tiempoRealMin;
  final double? errorAbsolutoMin;
  final double? errorPorcentual;
  final int? latenciaRespuestaMs;

  /// ISO 8601
  final String fechaCalculo;
  final bool esSimulado;

  const Estimacion({
    required this.idEstimacion,
    required this.idUnidad,
    required this.idParadaObjetivo,
    required this.distanciaRestanteM,
    required this.velocidadSuavizadaKmh,
    required this.condicionTrafico,
    required this.fuenteCalculo,
    required this.etaEstimadoMin,
    this.tiempoRealMin,
    this.errorAbsolutoMin,
    this.errorPorcentual,
    this.latenciaRespuestaMs,
    required this.fechaCalculo,
    required this.esSimulado,
  });
}

class Incidencia {
  final int idIncidencia;
  final int? idRutaAfectada;
  final String tipoIncidencia;
  final String descripcion;
  final double? retrasoEstimadoMin;
  final Coordenada? ubicacion;
  final bool activa;
  final String fechaReporte;
  final FuenteDatos fuenteDatos;

  const Incidencia({
    required this.idIncidencia,
    required this.idRutaAfectada,
    required this.tipoIncidencia,
    required this.descripcion,
    required this.retrasoEstimadoMin,
    required this.ubicacion,
    required this.activa,
    required this.fechaReporte,
    required this.fuenteDatos,
  });
}

/// Resultado de consultar un proveedor de ruteo vial.
class RespuestaRuteo {
  final double distanciaM;
  final double duracionS;
  final FuenteCalculo fuente;
  const RespuestaRuteo({required this.distanciaM, required this.duracionS, required this.fuente});
}

abstract class ProveedorRuteo {
  String get nombre;

  /// Debe lanzar una excepción si el proveedor falla o no encuentra ruta.
  Future<RespuestaRuteo> obtenerRuta(Coordenada origen, Coordenada destino);
}
