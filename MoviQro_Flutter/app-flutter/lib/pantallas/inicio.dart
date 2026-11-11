import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/tema.dart';
import '../core/core.dart';
import '../estado/datos_modelo.dart';
import '../servicios/favoritos.dart';
import '../servicios/proveedor_datos.dart';
import '../widgets/comunes.dart';
import '../widgets/tarjeta_ruta.dart';
import 'detalle_ruta.dart';
import 'incidencias.dart';
import 'transmisor.dart';

class PantallaInicio extends StatefulWidget {
  /// Cambia a la pestaña de rutas con una consulta opcional.
  final void Function(String consulta) irARutas;
  const PantallaInicio({super.key, required this.irARutas});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosModelo>();
    final fav = context.watch<Favoritos>();
    final favoritas = datos.rutas.where((r) => fav.esFavorita(r.ruta.numeroRuta)).toList();
    final hayDemo = datos.modo == ModoDatos.local || datos.rutas.any((r) => r.ruta.fuenteDatos == FuenteDatos.demostracion);

    return PantallaBase(
      alActualizar: datos.recargar,
      hijos: [
        const Text('MoviQro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colores.azul)),
        const SizedBox(height: 18),
        const Text('TRANSPORTE PÚBLICO', style: TextStyle(color: Colores.atenuado, fontSize: 12)),
        const SizedBox(height: 8),
        const Text.rich(TextSpan(children: [
          TextSpan(text: 'Tu ciudad,\n'),
          TextSpan(text: 'en movimiento.', style: TextStyle(color: Colores.azul)),
        ]), style: TextStyle(fontSize: 28, height: 1.25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => widget.irARutas(v.trim()),
          decoration: InputDecoration(
            hintText: '¿A dónde quieres ir?',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colores.buscador,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colores.buscadorBorde)),
            suffixIcon: IconButton(
              tooltip: 'Buscar',
              icon: const Icon(Icons.arrow_forward, color: Colores.azul),
              onPressed: () => widget.irARutas(_ctrl.text.trim()),
            ),
          ),
        ),
        const SizedBox(height: 22),
        InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: () => widget.irARutas(''),
          child: Container(
            height: 170,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF143C69), border: Border.all(color: const Color(0xFF294969)), borderRadius: BorderRadius.circular(19)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('VIAJA MÁS FÁCIL', style: TextStyle(color: Color(0xFFBCDCFF), fontSize: 10, letterSpacing: 1.5)),
              SizedBox(height: 8),
              Text('Muévete por\ntu ciudad.', style: TextStyle(fontSize: 26, height: 1.15, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Guarda tus rutas favoritas y conoce sus paradas.', style: TextStyle(color: Color(0xFFE3EEFF), fontSize: 12)),
              SizedBox(height: 8),
              Text('Explorar rutas  →', style: TextStyle(color: Colores.favorito, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Rutas favoritas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          TextButton(onPressed: () => widget.irARutas(''), child: const Text('Explorar rutas ↗')),
        ]),
        const SizedBox(height: 8),
        if (datos.cargando && datos.rutas.isEmpty)
          const EstadoCarga('Cargando rutas…')
        else if (datos.error != null)
          EstadoError(mensaje: datos.error!, alReintentar: datos.recargar)
        else if (favoritas.isEmpty)
          EstadoVacio(
            'Aún no tienes rutas favoritas. Explora las rutas y toca ☆ para guardar una.',
            accion: TextButton(onPressed: () => widget.irARutas(''), child: const Text('Explorar rutas →')),
          )
        else
          for (final r in favoritas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TarjetaRuta(
                ruta: r.ruta,
                alAbrir: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PantallaDetalleRuta(numeroRuta: r.ruta.numeroRuta))),
              ),
            ),
        const SizedBox(height: 14),
        _Atajo(
          titulo: '⚑  Incidencias viales',
          subtitulo: datos.incidencias.isEmpty ? 'Sin incidencias activas registradas ›' : '${datos.incidencias.length} activa(s) ›',
          alTocar: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PantallaIncidencias())),
        ),
        const SizedBox(height: 12),
        CajaInfo(
          titulo: 'Planifica tu viaje',
          texto: 'Consulta los puntos de paso de cada ruta y la ubicación de las unidades cuando estén disponibles.'
              '${hayDemo ? ' Los recorridos y posiciones etiquetados como "Demostración" son ilustrativos y deben verificarse con información oficial antes de viajar.' : ''}',
        ),
        const SizedBox(height: 12),
        _Atajo(
          titulo: '⌖  Modo conductor',
          subtitulo: 'Transmisor GPS para unidades autorizadas ›',
          alTocar: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PantallaTransmisor())),
        ),
      ],
    );
  }
}

class _Atajo extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final VoidCallback alTocar;
  const _Atajo({required this.titulo, required this.subtitulo, required this.alTocar});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: alTocar,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colores.panel, border: Border.all(color: Colores.linea), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 5),
            Text(subtitulo, style: const TextStyle(color: Colores.atenuado, fontSize: 11)),
          ]),
        ),
      );
}
