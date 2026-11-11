import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/entorno.dart';
import '../core/core.dart';

enum ModoTransmision { real, demostracion }

enum EstadoTransmision { detenido, iniciando, activo, sinPermiso, error }

class EstadisticasTransmision {
  final EstadoTransmision estado;
  final int enviadas;
  final int pendientes;
  final int descartadas;
  final String? ultimoError;
  final LecturaGps? ultimaLectura;

  /// Milisegundos que tardó el último envío (ida y vuelta al servidor).
  final int? ultimaDuracionEnvioMs;

  const EstadisticasTransmision({
    this.estado = EstadoTransmision.detenido,
    this.enviadas = 0,
    this.pendientes = 0,
    this.descartadas = 0,
    this.ultimoError,
    this.ultimaLectura,
    this.ultimaDuracionEnvioMs,
  });

  EstadisticasTransmision copiarCon({
    EstadoTransmision? estado,
    int? enviadas,
    int? pendientes,
    int? descartadas,
    Object? ultimoError = _sinCambio,
    LecturaGps? ultimaLectura,
    int? ultimaDuracionEnvioMs,
  }) =>
      EstadisticasTransmision(
        estado: estado ?? this.estado,
        enviadas: enviadas ?? this.enviadas,
        pendientes: pendientes ?? this.pendientes,
        descartadas: descartadas ?? this.descartadas,
        ultimoError: identical(ultimoError, _sinCambio) ? this.ultimoError : ultimoError as String?,
        ultimaLectura: ultimaLectura ?? this.ultimaLectura,
        ultimaDuracionEnvioMs: ultimaDuracionEnvioMs ?? this.ultimaDuracionEnvioMs,
      );
}

const Object _sinCambio = Object();

/// Escribe un lote de filas en coordenadas_log. Lanza si falla (sin red, RLS, etc.).
typedef EnviarLote = Future<void> Function(List<Map<String, Object?>> filas);

/// Envío real a Supabase (requiere sesión de un usuario autorizado en autorizaciones_transmision).
EnviarLote enviarASupabase(SupabaseClient db) =>
    (filas) async {
      await db.from('coordenadas_log').insert(filas);
    };

/// Transmisor GPS (módulo emisor).
///  - Captura latitud, longitud, velocidad (km/h), marca de tiempo y precisión.
///  - Valida cada lectura; descarta las inválidas sin interrumpir la captura.
///  - Acumula hasta 20 posiciones en un buffer y reintenta ante fallos de conectividad.
///  - Modo demostración: desplaza una unidad simulada por la ruta (lecturas marcadas simulado)
///    y NO escribe en la base de datos (la política RLS solo admite origen 'real').
///  - Segundo plano: servicio en primer plano de Android vía geolocator. NO VERIFICADO en dispositivo.
class TransmisorGps {
  final int idUnidad;
  final Duration intervalo;
  final ModoTransmision modo;
  final bool segundoPlano;
  final List<Coordenada>? trazadoDemo;
  final EnviarLote? enviar;
  final void Function(EstadisticasTransmision) alCambiar;

  final BufferTelemetria _buffer = BufferTelemetria(Parametros.maxBufferTransmision);
  StreamSubscription<Position>? _suscripcion;
  Timer? _temporizador;
  bool _activo = false;
  EstadisticasTransmision _est = const EstadisticasTransmision();

  TransmisorGps({
    required this.idUnidad,
    required this.intervalo,
    required this.modo,
    this.segundoPlano = false,
    this.trazadoDemo,
    required this.enviar,
    required this.alCambiar,
  });

  EstadisticasTransmision get estadisticas => _est;

  void _publicar({
    EstadoTransmision? estado,
    int? enviadas,
    Object? ultimoError = _sinCambio,
    LecturaGps? ultimaLectura,
    int? ultimaDuracionEnvioMs,
  }) {
    _est = _est.copiarCon(
      estado: estado,
      enviadas: enviadas,
      pendientes: _buffer.tamano,
      descartadas: _buffer.descartadas,
      ultimoError: ultimoError,
      ultimaLectura: ultimaLectura,
      ultimaDuracionEnvioMs: ultimaDuracionEnvioMs,
    );
    alCambiar(_est);
  }

  Future<void> iniciar() async {
    if (_activo) return;
    _activo = true;
    _publicar(estado: EstadoTransmision.iniciando, ultimoError: null);

    if (modo == ModoTransmision.demostracion) {
      final traz = trazadoDemo;
      if (traz == null || traz.length < 2) {
        _activo = false;
        _publicar(estado: EstadoTransmision.error, ultimoError: 'No hay trazado disponible para la demostración.');
        return;
      }
      final sim = SimuladorUnidad(
        trazado: traz,
        velocidadKmh: 35,
        intervaloS: intervalo.inMilliseconds / 1000,
        bucle: true,
        tiempoInicialMs: DateTime.now().millisecondsSinceEpoch,
      );
      _publicar(estado: EstadoTransmision.activo);
      _temporizador = Timer.periodic(intervalo, (_) {
        _procesar(sim.avanzar().copiarCon(timestampMs: DateTime.now().millisecondsSinceEpoch));
      });
      return;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _activo = false;
        _publicar(estado: EstadoTransmision.error, ultimoError: 'El GPS del dispositivo está desactivado. Actívalo en los ajustes.');
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        _activo = false;
        _publicar(
          estado: EstadoTransmision.sinPermiso,
          ultimoError: 'Se necesita el permiso de ubicación para transmitir. Actívalo en los ajustes del dispositivo.',
        );
        return;
      }
      if (segundoPlano) {
        // Android 10+: "Permitir siempre" y notificaciones (Android 13+) para el servicio en primer plano.
        await Permission.locationAlways.request();
        await Permission.notification.request();
      }

      final settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: intervalo,
        foregroundNotificationConfig: segundoPlano
            ? const ForegroundNotificationConfig(
                notificationTitle: 'MoviQro · transmitiendo posición',
                notificationText: 'La posición de la unidad se envía mientras el modo conductor está activo.',
                enableWakeLock: true,
                setOngoing: true,
              )
            : null,
      );
      _suscripcion = Geolocator.getPositionStream(locationSettings: settings).listen(
        (pos) {
          _procesar(LecturaGps(
            latitud: pos.latitude,
            longitud: pos.longitude,
            velocidadKmh: velocidadDispositivoAKmh(pos.speed),
            precisionM: pos.accuracy,
            timestampMs: pos.timestamp.millisecondsSinceEpoch,
            // Android marca las ubicaciones falsas (apps de "mock location"): no se tratan como reales.
            origen: pos.isMocked ? OrigenDato.simulado : OrigenDato.real,
          ));
        },
        onError: (Object e) => _publicar(ultimoError: 'Error del GPS: $e'),
      );
      _publicar(estado: EstadoTransmision.activo);
    } catch (e) {
      _activo = false;
      _publicar(estado: EstadoTransmision.error, ultimoError: 'No se pudo iniciar el GPS: $e');
    }
  }

  Future<void> _procesar(LecturaGps lectura) async {
    final v = validarCoordenadas(lectura.latitud, lectura.longitud);
    if (!v.valido) {
      _publicar(ultimoError: 'Lectura descartada: ${v.motivo}');
      return;
    }
    _buffer.agregar(lectura);
    _publicar(ultimaLectura: lectura);

    final envio = enviar;
    // Las lecturas simuladas no se envían desde la app: la política RLS solo admite origen 'real'.
    if (envio == null || lectura.origen == OrigenDato.simulado) {
      if (lectura.origen == OrigenDato.simulado) {
        await _buffer.vaciar((_) async {});
        _publicar();
      }
      return;
    }
    final t0 = DateTime.now().millisecondsSinceEpoch;
    final r = await _buffer.vaciar((lote) => envio([for (final l in lote) aFilaCoordenadasLog(idUnidad, l)]));
    if (r.error != null) {
      _publicar(ultimoError: 'Sin conexión o rechazo del servidor: ${r.error}. Se reintentará (${_buffer.tamano} en buffer).');
    } else if (r.enviadas > 0) {
      _publicar(
        enviadas: _est.enviadas + r.enviadas,
        ultimoError: null,
        ultimaDuracionEnvioMs: DateTime.now().millisecondsSinceEpoch - t0,
      );
    }
  }

  Future<void> detener() async {
    _activo = false;
    await _suscripcion?.cancel();
    _suscripcion = null;
    _temporizador?.cancel();
    _temporizador = null;
    _publicar(estado: EstadoTransmision.detenido);
  }
}
