import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoritos persistentes (SharedPreferences). Misma clave que el prototipo HTML.
/// Guarda números de ruta.
class Favoritos extends ChangeNotifier {
  static const String _clave = 'moviqro-favorite-routes';

  List<String> _lista = const [];
  bool _cargado = false;

  List<String> get lista => _lista;
  bool get cargado => _cargado;
  bool esFavorita(String numeroRuta) => _lista.contains(numeroRuta);

  /// Carga desde disco. Devuelve un mensaje de error comprensible si falla (y sigue con lista vacía).
  Future<String?> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bruto = prefs.getString(_clave);
      if (bruto != null) {
        final parsed = jsonDecode(bruto);
        if (parsed is! List) throw const FormatException('formato inválido');
        _lista = parsed.whereType<String>().toList();
      }
      _cargado = true;
      notifyListeners();
      return null;
    } catch (_) {
      _lista = const [];
      _cargado = true;
      notifyListeners();
      return 'No se pudieron cargar tus rutas favoritas.';
    }
  }

  /// Agrega o quita. Devuelve null si se guardó, o un mensaje de error (sin cambiar el estado).
  Future<String?> alternar(String numeroRuta) async {
    final siguiente = _lista.contains(numeroRuta)
        ? _lista.where((x) => x != numeroRuta).toList()
        : [..._lista, numeroRuta];
    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(_clave, jsonEncode(siguiente));
      if (!ok) return 'No se pudo guardar la ruta. Revisa el almacenamiento del dispositivo.';
    } catch (_) {
      return 'No se pudo guardar la ruta. Revisa el almacenamiento del dispositivo.';
    }
    _lista = siguiente;
    notifyListeners();
    return null;
  }
}
