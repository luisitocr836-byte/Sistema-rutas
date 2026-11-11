import 'package:flutter/material.dart';

import '../widgets/banner_conexion.dart';
import 'favoritos.dart';
import 'inicio.dart';
import 'mapa.dart';
import 'rutas.dart';
import 'seguimiento.dart';

/// Navegación inferior: Inicio · Rutas · Mapa · Seguimiento · Favoritos.
class PantallaRaiz extends StatefulWidget {
  const PantallaRaiz({super.key});

  @override
  State<PantallaRaiz> createState() => _PantallaRaizState();
}

class _PantallaRaizState extends State<PantallaRaiz> {
  int _indice = 0;
  String _consulta = '';
  int _versionRutas = 0;

  void _irARutas(String consulta) => setState(() {
        _consulta = consulta;
        _versionRutas++;
        _indice = 1;
      });

  @override
  Widget build(BuildContext context) {
    final paginas = <Widget>[
      PantallaInicio(irARutas: _irARutas),
      PantallaRutas(key: ValueKey('rutas_$_versionRutas'), consultaInicial: _consulta),
      const PantallaMapa(),
      const PantallaSeguimiento(),
      PantallaFavoritos(irARutas: () => _irARutas('')),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const BannerConexion(),
          Expanded(child: IndexedStack(index: _indice, children: paginas)),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.alt_route), label: 'Rutas'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.directions_bus_outlined), selectedIcon: Icon(Icons.directions_bus), label: 'Seguimiento'),
          NavigationDestination(icon: Icon(Icons.star_border), selectedIcon: Icon(Icons.star), label: 'Favoritos'),
        ],
      ),
    );
  }
}
