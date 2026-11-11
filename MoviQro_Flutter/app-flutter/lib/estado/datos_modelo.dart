import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/core.dart';
import '../servicios/proveedor_datos.dart';
import '../utilidades/formato.dart';

/// Estado global de datos (rutas, unidades, estimaciones, incidencias) con suscripciones en vivo.
class DatosModelo extends ChangeNotifier {
  final ProveedorDatos _p;
  DatosModelo(this._p);

  List<RutaConParadas> rutas = const [];
  bool cargando = true;

  /// Mensaje comprensible si la carga falló; null si todo bien.
  String? error;
  final Map<int, Unidad> unidades = {};

  /// Última estimación recibida por id de unidad.
  final Map<int, Estimacion> estimaciones = {};
  List<Incidencia> incidencias = const [];
  EstadoRealtime estadoRealtime = EstadoRealtime.conectando;

  Cancelar? _cancelarUnidades;
  Cancelar? _cancelarEstimaciones;
  bool _destruido = false;

  ModoDatos get modo => _p.modo;

  Future<void> iniciar() async {
    await recargar();
    _cancelarUnidades = _p.suscribirUnidades(
      (u) {
        unidades[u.idUnidad] = u;
        _avisar();
      },
      alEstado: (e) {
        estadoRealtime = e;
        _avisar();
      },
    );
    _cancelarEstimaciones = _p.suscribirEstimaciones((e) {
      estimaciones[e.idUnidad] = e;
      _avisar();
    });
  }

  Future<void> recargar() async {
    cargando = true;
    error = null;
    _avisar();
    try {
      final r = await Future.wait([
        _p.listarRutas(),
        _p.listarUnidades(),
        _p.listarIncidencias(),
        _p.ultimasEstimaciones(),
      ]);
      rutas = r[0] as List<RutaConParadas>;
      unidades
        ..clear()
        ..addEntries((r[1] as List<Unidad>).map((u) => MapEntry(u.idUnidad, u)));
      incidencias = r[2] as List<Incidencia>;
      estimaciones
        ..clear()
        ..addEntries((r[3] as List<Estimacion>).map((e) => MapEntry(e.idUnidad, e)));
    } catch (e) {
      error = mensajeDeError(e);
    } finally {
      cargando = false;
      _avisar();
    }
  }

  RutaConParadas? rutaPorNumero(String numero) {
    for (final r in rutas) {
      if (r.ruta.numeroRuta == numero) return r;
    }
    return null;
  }

  /// Primera unidad asignada a la ruta (o null).
  Unidad? unidadDeRuta(int idRuta) {
    for (final u in unidades.values) {
      if (u.idRuta == idRuta) return u;
    }
    return null;
  }

  void _avisar() {
    if (!_destruido) notifyListeners();
  }

  @override
  void dispose() {
    _destruido = true;
    _cancelarUnidades?.call();
    _cancelarEstimaciones?.call();
    super.dispose();
  }
}
