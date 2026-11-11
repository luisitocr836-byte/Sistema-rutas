import 'package:flutter/material.dart';

/// Identidad visual tomada del prototipo HTML de MoviQro (modo oscuro, acciones en azul).
class Colores {
  static const fondo = Color(0xFF121212);
  static const fondoApp = Color(0xFF09090B);
  static const panel = Color(0xFF1D1D20);
  static const panel2 = Color(0xFF25252A);
  static const linea = Color(0xFF35353C);
  static const texto = Color(0xFFF5F5F7);
  static const atenuado = Color(0xFFA2A2AD);
  static const azul = Color(0xFF1687FF);
  static const azulOscuro = Color(0xFF075AC5);
  static const ocre = Color(0xFFA77943);
  static const rosa = Color(0xFFED69B5);
  static const buscador = Color(0xFF222934);
  static const buscadorBorde = Color(0xFF303B4C);
  static const favorito = Color(0xFFFFD166);
  static const cajaInfo = Color(0xFF1C2938);
  static const cajaInfoBorde = Color(0xFF2B435D);
  static const cajaInfoTexto = Color(0xFFC9D8E9);
  static const navegacion = Color(0xFF19191C);
  static const exito = Color(0xFFA3F0C3);
  static const exitoFondo = Color(0xFF19392D);
  static const alerta = Color(0xFFF1D6A5);
  static const alertaFondo = Color(0xFF2C2418);
  static const alertaBorde = Color(0xFF66502D);
  static const error = Color(0xFFFFB4AB);
  static const errorFondo = Color(0xFF3A1F1F);
}

Color colorDeHex(String? hex, [Color porDefecto = Colores.azul]) {
  if (hex == null) return porDefecto;
  final limpio = hex.replaceFirst('#', '');
  if (limpio.length != 6) return porDefecto;
  final v = int.tryParse(limpio, radix: 16);
  return v == null ? porDefecto : Color(0xFF000000 | v);
}

ThemeData temaMoviqro() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Colores.fondo,
    colorScheme: const ColorScheme.dark(
      primary: Colores.azul,
      secondary: Colores.ocre,
      surface: Colores.panel,
      error: Colores.error,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Colores.fondo, foregroundColor: Colores.texto, elevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colores.navegacion,
      indicatorColor: Colores.azulOscuro,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, color: Colores.texto)),
    ),
    textTheme: base.textTheme.apply(bodyColor: Colores.texto, displayColor: Colores.texto),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
