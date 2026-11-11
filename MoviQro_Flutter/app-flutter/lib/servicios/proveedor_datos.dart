import '../core/core.dart';

enum ModoDatos { supabase, local }

enum EstadoRealtime { conectando, conectado, error, cerrado }

typedef Cancelar = void Function();

/// Contrato de acceso a datos de la UI. Hay dos implementaciones: Supabase y local (demostración).
abstract class ProveedorDatos {
  /// supabase = datos de la base; local = datos y unidades SIMULADOS incluidos en la app.
  ModoDatos get modo;
  Future<List<RutaConParadas>> listarRutas();
  Future<List<Unidad>> listarUnidades();
  Future<List<Incidencia>> listarIncidencias();

  /// Última estimación por unidad (puede no haber ninguna).
  Future<List<Estimacion>> ultimasEstimaciones();
  Cancelar suscribirUnidades(void Function(Unidad) alCambiar, {void Function(EstadoRealtime)? alEstado});
  Cancelar suscribirEstimaciones(void Function(Estimacion) alLlegar);
}
