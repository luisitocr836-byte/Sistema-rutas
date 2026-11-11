/// Configuración inyectada en compilación con `--dart-define-from-file=config/app.json`.
///
/// La clave "anon" de Supabase es pública por diseño (la protege RLS). La clave service_role
/// JAMÁS debe incluirse en la app. Sin SUPABASE_URL/ANON_KEY la app funciona en modo local de demostración.
class Entorno {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const bool forzarLocal = bool.fromEnvironment('FORZAR_MODO_LOCAL');
  static const int _intervaloBruto = int.fromEnvironment('TRANSMISION_INTERVALO_S', defaultValue: 4);

  /// true si hay URL https y clave, y no se forzó el modo local.
  static bool get supabaseConfigurado =>
      !forzarLocal &&
      supabaseUrl.startsWith('https://') &&
      supabaseAnonKey.length > 20 &&
      !supabaseAnonKey.startsWith('TU_');

  /// Intervalo de transmisión GPS por defecto (s). Avance 2: 3–5 s.
  static int get intervaloTransmisionS => (_intervaloBruto >= 1 && _intervaloBruto <= 60) ? _intervaloBruto : 4;
}

/// Parámetros operativos de la app.
class Parametros {
  /// Una unidad sin reporte desde hace más de esto (s) se muestra como "sin señal GPS reciente".
  static const int edadMaximaPosicionS = 60;

  /// Una estimación más vieja que esto (s) se marca como desactualizada.
  static const int edadMaximaEstimacionS = 90;
  static const double radioRutasCercanasM = 1000;
  static const int maxBufferTransmision = 20;
}
