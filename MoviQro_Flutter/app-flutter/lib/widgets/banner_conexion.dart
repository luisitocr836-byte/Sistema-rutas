import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../config/tema.dart';

/// Muestra un aviso cuando el dispositivo no tiene conexión.
class BannerConexion extends StatefulWidget {
  const BannerConexion({super.key});

  @override
  State<BannerConexion> createState() => _BannerConexionState();
}

class _BannerConexionState extends State<BannerConexion> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _sinConexion = false;

  bool _esSinConexion(List<ConnectivityResult> r) => r.isEmpty || r.every((x) => x == ConnectivityResult.none);

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((r) {
      if (mounted) setState(() => _sinConexion = _esSinConexion(r));
    }).catchError((_) {});
    _sub = Connectivity().onConnectivityChanged.listen((r) {
      if (mounted) setState(() => _sinConexion = _esSinConexion(r));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sinConexion) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colores.alertaFondo,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: const Text(
        'Sin conexión. Se muestran los últimos datos disponibles.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colores.alerta, fontSize: 12),
      ),
    );
  }
}
