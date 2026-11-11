import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/tema.dart';
import '../core/core.dart';
import '../utilidades/formato.dart';

LatLng _ll(Coordenada c) => LatLng(c.latitud, c.longitud);

/// Mapa nativo (Google Maps) con polilíneas de ruta, marcadores de paradas y de unidades.
/// Las unidades simuladas se muestran en naranja y con la etiqueta "Demostración".
class MapaRuta extends StatefulWidget {
  final List<RutaConParadas> rutas;
  final Map<int, Unidad> unidades;
  final double? altura;
  final int? idParadaObjetivo;
  final Coordenada? miUbicacion;

  /// Cambiar este valor fuerza a recentrar la cámara (p. ej. al pulsar "Mi ubicación").
  final int versionCamara;

  const MapaRuta({
    super.key,
    required this.rutas,
    required this.unidades,
    this.altura = 260,
    this.idParadaObjetivo,
    this.miUbicacion,
    this.versionCamara = 0,
  });

  @override
  State<MapaRuta> createState() => _MapaRutaState();
}

class _MapaRutaState extends State<MapaRuta> {
  GoogleMapController? _ctrl;

  static const _centroPorDefecto = LatLng(20.3875, -99.9850);

  @override
  void didUpdateWidget(covariant MapaRuta old) {
    super.didUpdateWidget(old);
    final ids = widget.rutas.map((r) => r.ruta.idRuta).join(',');
    final idsAntes = old.rutas.map((r) => r.ruta.idRuta).join(',');
    if (ids != idsAntes) _ajustar();
    if (widget.versionCamara != old.versionCamara && widget.miUbicacion != null) {
      _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(_ll(widget.miUbicacion!), 15));
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _ajustar() async {
    final puntos = [for (final r in widget.rutas) ...r.ruta.trazado];
    final c = _ctrl;
    if (c == null || puntos.isEmpty) return;
    var minLat = puntos.first.latitud, maxLat = minLat, minLon = puntos.first.longitud, maxLon = minLon;
    for (final p in puntos) {
      if (p.latitud < minLat) minLat = p.latitud;
      if (p.latitud > maxLat) maxLat = p.latitud;
      if (p.longitud < minLon) minLon = p.longitud;
      if (p.longitud > maxLon) maxLon = p.longitud;
    }
    try {
      // Esperar a que el mapa tenga tamaño antes de encuadrar.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      if (minLat == maxLat && minLon == maxLon) {
        await c.animateCamera(CameraUpdate.newLatLngZoom(LatLng(minLat, minLon), 15));
      } else {
        await c.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: LatLng(minLat, minLon), northeast: LatLng(maxLat, maxLon)),
          48,
        ));
      }
    } catch (_) {
      // El encuadre es solo cosmético; si el mapa aún no está listo se ignora.
    }
  }

  @override
  Widget build(BuildContext context) {
    final polilineas = <Polyline>{};
    final marcadores = <Marker>{};
    final idsRutas = widget.rutas.map((r) => r.ruta.idRuta).toSet();

    for (final rp in widget.rutas) {
      polilineas.add(Polyline(
        polylineId: PolylineId('ruta_${rp.ruta.idRuta}'),
        points: rp.ruta.trazado.map(_ll).toList(),
        color: colorDeHex(rp.ruta.colorHex),
        width: 5,
      ));
      for (final p in rp.paradas) {
        marcadores.add(Marker(
          markerId: MarkerId('parada_${p.idParada}'),
          position: _ll(p),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            p.idParada == widget.idParadaObjetivo ? BitmapDescriptor.hueRose : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: '${p.ordenSecuencia}. ${p.nombre}', snippet: p.referenciaVial),
        ));
      }
    }

    final ahora = DateTime.now().millisecondsSinceEpoch;
    for (final u in widget.unidades.values) {
      if (!u.tienePosicion || (u.idRuta != null && !idsRutas.contains(u.idRuta))) continue;
      final simulada = u.ultimoOrigenDato == OrigenDato.simulado;
      final estado = estadoDeUnidad(u, ahora);
      marcadores.add(Marker(
        markerId: MarkerId('unidad_${u.idUnidad}'),
        position: LatLng(u.ultimaLatitud!, u.ultimaLongitud!),
        icon: BitmapDescriptor.defaultMarkerWithHue(simulada ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: '${u.numeroEconomico}${simulada ? ' · Demostración' : ''}',
          snippet: '${textoEstadoUnidad[estado]} · ${formatearKmh(u.ultimaVelocidadKmh)}',
        ),
      ));
    }

    final mi = widget.miUbicacion;
    if (mi != null) {
      marcadores.add(Marker(
        markerId: const MarkerId('mi_ubicacion'),
        position: _ll(mi),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ));
    }

    final mapa = GoogleMap(
      initialCameraPosition: const CameraPosition(target: _centroPorDefecto, zoom: 13),
      polylines: polilineas,
      markers: marcadores,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      onMapCreated: (c) {
        _ctrl = c;
        unawaited(_ajustar());
      },
    );

    if (widget.altura == null) return mapa;
    return ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(height: widget.altura, child: mapa));
  }
}
