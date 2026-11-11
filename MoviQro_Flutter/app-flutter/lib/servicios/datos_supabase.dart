import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/core.dart';
import 'proveedor_datos.dart';

typedef _Fila = Map<String, dynamic>;

double? _d(Object? x) => x is num ? x.toDouble() : (x is String ? double.tryParse(x) : null);
int? _i(Object? x) => x is num ? x.toInt() : (x is String ? int.tryParse(x) : null);

Unidad _aUnidad(_Fila d) => Unidad(
      idUnidad: _i(d['id_unidad'])!,
      idRuta: _i(d['id_ruta']),
      numeroEconomico: (d['numero_economico'] ?? '').toString(),
      estadoOperativo: (d['estado_operativo'] ?? '').toString(),
      ultimaLatitud: _d(d['ultima_latitud']),
      ultimaLongitud: _d(d['ultima_longitud']),
      ultimaVelocidadKmh: _d(d['ultima_velocidad_kmh']),
      ultimaActualizacion: d['ultima_actualizacion'] as String?,
      ultimoOrigenDato: OrigenDato.desdeDb(d['ultimo_origen_dato'] as String?),
    );

Estimacion _aEstimacion(_Fila d) => Estimacion(
      idEstimacion: _i(d['id_estimacion'])!,
      idUnidad: _i(d['id_unidad'])!,
      idParadaObjetivo: _i(d['id_parada_objetivo'])!,
      distanciaRestanteM: _d(d['distancia_restante_m']) ?? 0,
      velocidadSuavizadaKmh: _d(d['velocidad_suavizada_kmh']),
      condicionTrafico: CondicionTrafico.desdeDb(d['condicion_trafico'] as String?),
      fuenteCalculo: FuenteCalculo.desdeDb(d['fuente_calculo'] as String?),
      etaEstimadoMin: _d(d['eta_estimado_min']) ?? 0,
      tiempoRealMin: _d(d['tiempo_real_min']),
      errorAbsolutoMin: _d(d['error_absoluto_min']),
      errorPorcentual: _d(d['error_porcentual']),
      latenciaRespuestaMs: _i(d['latencia_respuesta_ms']),
      fechaCalculo: (d['fecha_calculo'] ?? '').toString(),
      esSimulado: d['es_simulado'] == true,
    );

Object? _jsonSiTexto(Object? x) => x is String ? jsonDecode(x) : x;

class DatosSupabase implements ProveedorDatos {
  final SupabaseClient _db;
  DatosSupabase(this._db);

  @override
  ModoDatos get modo => ModoDatos.supabase;

  @override
  Future<List<RutaConParadas>> listarRutas() async {
    final rutas = await _db.from('v_rutas').select().order('numero_ruta');
    final paradas = await _db.from('v_paradas').select().order('orden_secuencia');
    return [
      for (final r in rutas)
        RutaConParadas(
          ruta: Ruta(
            idRuta: _i(r['id_ruta'])!,
            numeroRuta: r['numero_ruta'].toString(),
            nombre: r['nombre'].toString(),
            origen: r['origen'].toString(),
            destino: r['destino'].toString(),
            distanciaKm: _d(r['distancia_km']),
            colorHex: r['color_hex'] as String?,
            horarioInicio: r['horario_inicio'] as String?,
            horarioFin: r['horario_fin'] as String?,
            frecuenciaPromedioMin: _i(r['frecuencia_promedio_min']),
            activa: r['activa'] != false,
            trazado: lineStringGeoJsonACoordenadas(_jsonSiTexto(r['trazado_geojson'])),
            fuenteDatos: FuenteDatos.desdeDb(r['fuente_datos'] as String?),
          ),
          paradas: [
            for (final p in paradas)
              if (_i(p['id_ruta']) == _i(r['id_ruta']))
                Parada(
                  idParada: _i(p['id_parada'])!,
                  idRuta: _i(p['id_ruta'])!,
                  nombre: p['nombre'].toString(),
                  referenciaVial: p['referencia_vial'] as String?,
                  ordenSecuencia: _i(p['orden_secuencia'])!,
                  esNodoTransferencia: p['es_nodo_transferencia'] == true,
                  latitud: _d(p['latitud'])!,
                  longitud: _d(p['longitud'])!,
                ),
          ],
        ),
    ];
  }

  @override
  Future<List<Unidad>> listarUnidades() async {
    final filas = await _db.from('unidades').select();
    return filas.map(_aUnidad).toList();
  }

  @override
  Future<List<Incidencia>> listarIncidencias() async {
    final filas = await _db.from('v_incidencias').select().eq('activa', true).order('fecha_reporte', ascending: false);
    return [
      for (final i in filas)
        Incidencia(
          idIncidencia: _i(i['id_incidencia'])!,
          idRutaAfectada: _i(i['id_ruta_afectada']),
          tipoIncidencia: i['tipo_incidencia'].toString(),
          descripcion: i['descripcion'].toString(),
          retrasoEstimadoMin: _d(i['retraso_estimado_min']),
          ubicacion: (_d(i['latitud']) != null && _d(i['longitud']) != null)
              ? Coordenada(_d(i['latitud'])!, _d(i['longitud'])!)
              : null,
          activa: i['activa'] == true,
          fechaReporte: i['fecha_reporte'].toString(),
          fuenteDatos: FuenteDatos.desdeDb(i['fuente_datos'] as String?),
        ),
    ];
  }

  @override
  Future<List<Estimacion>> ultimasEstimaciones() async {
    final desde = DateTime.now().toUtc().subtract(const Duration(minutes: 10)).toIso8601String();
    final filas = await _db
        .from('estimaciones_eta')
        .select()
        .gte('fecha_calculo', desde)
        .order('fecha_calculo', ascending: false)
        .limit(200);
    final vistas = <int>{};
    final resultado = <Estimacion>[];
    for (final f in filas) {
      final id = _i(f['id_unidad']);
      if (id == null || vistas.contains(id)) continue;
      vistas.add(id);
      resultado.add(_aEstimacion(f));
    }
    return resultado;
  }

  @override
  Cancelar suscribirUnidades(void Function(Unidad) alCambiar, {void Function(EstadoRealtime)? alEstado}) {
    final canal = _db
        .channel('app-unidades')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'unidades',
          callback: (payload) {
            final n = payload.newRecord;
            if (n.containsKey('id_unidad')) alCambiar(_aUnidad(n));
          },
        )
        .subscribe((estado, error) {
      alEstado?.call(switch (estado) {
        RealtimeSubscribeStatus.subscribed => EstadoRealtime.conectado,
        RealtimeSubscribeStatus.channelError => EstadoRealtime.error,
        RealtimeSubscribeStatus.timedOut => EstadoRealtime.error,
        RealtimeSubscribeStatus.closed => EstadoRealtime.cerrado,
      });
    });
    return () {
      _db.removeChannel(canal);
    };
  }

  @override
  Cancelar suscribirEstimaciones(void Function(Estimacion) alLlegar) {
    final canal = _db
        .channel('app-estimaciones')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'estimaciones_eta',
          callback: (payload) {
            final n = payload.newRecord;
            if (n.containsKey('id_estimacion')) alLlegar(_aEstimacion(n));
          },
        )
        .subscribe();
    return () {
      _db.removeChannel(canal);
    };
  }
}
