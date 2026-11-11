import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../config/entorno.dart';
import '../config/tema.dart';
import '../core/core.dart';
import '../estado/datos_modelo.dart';
import '../servicios/favoritos.dart';
import '../utilidades/formato.dart';
import '../widgets/comunes.dart';
import '../widgets/tarjeta_ruta.dart';
import 'detalle_ruta.dart';

enum _Filtro { todas, favoritas, cerca }

class PantallaRutas extends StatefulWidget {
  final String consultaInicial;
  const PantallaRutas({super.key, this.consultaInicial = ''});

  @override
  State<PantallaRutas> createState() => _PantallaRutasState();
}

class _PantallaRutasState extends State<PantallaRutas> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.consultaInicial);
  _Filtro _filtro = _Filtro.todas;
  Coordenada? _miPos;
  bool _buscandoUbicacion = false;
  String? _errorUbicacion;

  @override
  void didUpdateWidget(covariant PantallaRutas old) {
    super.didUpdateWidget(old);
    if (widget.consultaInicial != old.consultaInicial) {
      _ctrl.text = widget.consultaInicial;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Pide el permiso de ubicación de forma explícita (solo al tocar "Cerca de ti").
  Future<void> _activarCerca() async {
    setState(() {
      _buscandoUbicacion = true;
      _errorUbicacion = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'El GPS del dispositivo está desactivado.';
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        throw 'Sin permiso de ubicación. Actívalo en los ajustes para ver rutas cercanas.';
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      if (!mounted) return;
      setState(() {
        _miPos = Coordenada(pos.latitude, pos.longitude);
        _filtro = _Filtro.cerca;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorUbicacion = e is String ? e : 'No se pudo obtener tu ubicación. Inténtalo de nuevo.';
        _filtro = _Filtro.todas;
      });
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosModelo>();
    final fav = context.watch<Favoritos>();
    final q = normalizarTexto(_ctrl.text.trim());

    var lista = datos.rutas.where((r) {
      if (q.isEmpty) return true;
      final texto = normalizarTexto([
        r.ruta.numeroRuta, r.ruta.nombre, r.ruta.origen, r.ruta.destino,
        ...r.paradas.map((p) => p.nombre), ...r.paradas.map((p) => p.referenciaVial ?? ''),
      ].join(' '));
      return texto.contains(q);
    }).toList();

    if (_filtro == _Filtro.favoritas) {
      lista = lista.where((r) => fav.esFavorita(r.ruta.numeroRuta)).toList();
    }
    if (_filtro == _Filtro.cerca && _miPos != null) {
      lista = lista.where((r) => r.ruta.trazado.length >= 2 && proyectarEnRuta(r.ruta.trazado, _miPos!).distanciaALineaM <= Parametros.radioRutasCercanasM).toList();
    }

    return PantallaBase(
      titulo: 'Explorar rutas',
      alActualizar: datos.recargar,
      hijos: [
        TextField(
          controller: _ctrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar ruta, parada o destino',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colores.buscador,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colores.buscadorBorde)),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(tooltip: 'Borrar búsqueda', icon: const Icon(Icons.close), onPressed: () => setState(_ctrl.clear)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Todas'), selected: _filtro == _Filtro.todas, onSelected: (_) => setState(() => _filtro = _Filtro.todas)),
          ChoiceChip(label: const Text('Favoritas'), selected: _filtro == _Filtro.favoritas, onSelected: (_) => setState(() => _filtro = _Filtro.favoritas)),
          ChoiceChip(
            label: Text(_buscandoUbicacion ? 'Ubicando…' : 'Cerca de ti'),
            selected: _filtro == _Filtro.cerca,
            onSelected: _buscandoUbicacion ? null : (_) => _activarCerca(),
          ),
        ]),
        if (_errorUbicacion != null) ...[
          const SizedBox(height: 10),
          Text(_errorUbicacion!, style: const TextStyle(color: Colores.error, fontSize: 12)),
        ],
        if (_filtro == _Filtro.cerca && _miPos != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Rutas a menos de ${Parametros.radioRutasCercanasM.round()} m de tu ubicación.', style: const TextStyle(color: Colores.atenuado, fontSize: 12)),
          ),
        const SizedBox(height: 14),
        if (datos.cargando && datos.rutas.isEmpty)
          const EstadoCarga('Cargando rutas…')
        else if (datos.error != null)
          EstadoError(mensaje: datos.error!, alReintentar: datos.recargar)
        else if (lista.isEmpty)
          EstadoVacio(_filtro == _Filtro.cerca ? 'No hay rutas cerca de tu ubicación.' : 'No se encontraron rutas con ese criterio.')
        else
          for (final r in lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaRuta(
                ruta: r.ruta,
                alAbrir: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PantallaDetalleRuta(numeroRuta: r.ruta.numeroRuta))),
              ),
            ),
      ],
    );
  }
}
