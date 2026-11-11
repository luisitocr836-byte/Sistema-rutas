import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../config/tema.dart';
import '../core/core.dart';
import '../estado/datos_modelo.dart';
import '../widgets/comunes.dart';
import '../widgets/mapa_ruta.dart';

/// Mapa general: todas las rutas (o una seleccionada) con paradas y unidades.
class PantallaMapa extends StatefulWidget {
  const PantallaMapa({super.key});

  @override
  State<PantallaMapa> createState() => _PantallaMapaState();
}

class _PantallaMapaState extends State<PantallaMapa> {
  String? _seleccion; // número de ruta; null = todas
  Coordenada? _miPos;
  int _versionCamara = 0;
  bool _ubicando = false;

  Future<void> _miUbicacion() async {
    setState(() => _ubicando = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'El GPS del dispositivo está desactivado.';
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        throw 'Sin permiso de ubicación. Actívalo en los ajustes del dispositivo.';
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      if (!mounted) return;
      setState(() {
        _miPos = Coordenada(pos.latitude, pos.longitude);
        _versionCamara++;
      });
    } catch (e) {
      if (mounted) mostrarAviso(context, e is String ? e : 'No se pudo obtener tu ubicación.');
    } finally {
      if (mounted) setState(() => _ubicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosModelo>();
    final visibles = _seleccion == null ? datos.rutas : datos.rutas.where((r) => r.ruta.numeroRuta == _seleccion).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: SafeArea(
        child: datos.cargando && datos.rutas.isEmpty
            ? const EstadoCarga('Cargando mapa…')
            : datos.error != null && datos.rutas.isEmpty
                ? Padding(padding: const EdgeInsets.all(18), child: EstadoError(mensaje: datos.error!, alReintentar: datos.recargar))
                : Column(children: [
                    SizedBox(
                      height: 52,
                      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(label: const Text('Todas'), selected: _seleccion == null, onSelected: (_) => setState(() => _seleccion = null)),
                        ),
                        for (final r in datos.rutas)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('Ruta ${r.ruta.numeroRuta}'),
                              selected: _seleccion == r.ruta.numeroRuta,
                              selectedColor: colorDeHex(r.ruta.colorHex),
                              onSelected: (_) => setState(() => _seleccion = r.ruta.numeroRuta),
                            ),
                          ),
                      ]),
                    ),
                    Expanded(
                      child: Stack(children: [
                        MapaRuta(rutas: visibles, unidades: datos.unidades, altura: null, miUbicacion: _miPos, versionCamara: _versionCamara),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Wrap(spacing: 6, children: [
                            if (datos.rutas.any((r) => r.ruta.fuenteDatos == FuenteDatos.demostracion)) const InsigniaDato(TipoDato.demostracion),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ubicando ? null : _miUbicacion,
        icon: const Icon(Icons.my_location),
        label: Text(_ubicando ? 'Ubicando…' : 'Mi ubicación'),
      ),
    );
  }
}
