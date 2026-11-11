import 'dart:async';

import 'package:flutter/material.dart';

import '../config/tema.dart';

/// Reloj que se actualiza cada segundo para recalcular edades de datos.
class RelojBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, int ahoraMs) builder;
  const RelojBuilder({super.key, required this.builder});

  @override
  State<RelojBuilder> createState() => _RelojBuilderState();
}

class _RelojBuilderState extends State<RelojBuilder> {
  Timer? _t;
  int _ahora = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _ahora = DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ahora);
}

enum TipoDato { real, estimado, demostracion }

/// Etiqueta de procedencia del dato: GPS real / Estimado / Demostración.
class InsigniaDato extends StatelessWidget {
  final TipoDato tipo;
  const InsigniaDato(this.tipo, {super.key});

  @override
  Widget build(BuildContext context) {
    final (texto, fondo, color) = switch (tipo) {
      TipoDato.real => ('GPS real', Colores.exitoFondo, Colores.exito),
      TipoDato.estimado => ('Estimado', Colores.cajaInfo, Colores.cajaInfoTexto),
      TipoDato.demostracion => ('Demostración', Colores.alertaFondo, Colores.alerta),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class CajaInfo extends StatelessWidget {
  final String? titulo;
  final String texto;
  const CajaInfo({super.key, this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colores.cajaInfo,
          border: Border.all(color: Colores.cajaInfoBorde),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (titulo != null) Text(titulo!, style: const TextStyle(fontWeight: FontWeight.w700, color: Colores.texto)),
          if (titulo != null) const SizedBox(height: 4),
          Text(texto, style: const TextStyle(color: Colores.cajaInfoTexto, fontSize: 12, height: 1.4)),
        ]),
      );
}

class EstadoCarga extends StatelessWidget {
  final String mensaje;
  const EstadoCarga(this.mensaje, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(mensaje, style: const TextStyle(color: Colores.atenuado)),
          ]),
        ),
      );
}

class EstadoError extends StatelessWidget {
  final String mensaje;
  final VoidCallback alReintentar;
  const EstadoError({super.key, required this.mensaje, required this.alReintentar});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colores.errorFondo, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colores.error)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: alReintentar, child: const Text('Reintentar')),
        ]),
      );
}

class EstadoVacio extends StatelessWidget {
  final String mensaje;
  final Widget? accion;
  const EstadoVacio(this.mensaje, {super.key, this.accion});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colores.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colores.linea)),
        child: Column(children: [
          Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colores.atenuado)),
          if (accion != null) ...[const SizedBox(height: 8), accion!],
        ]),
      );
}

/// Contenedor estándar de pantalla: título opcional, pull-to-refresh y padding.
class PantallaBase extends StatelessWidget {
  final String? titulo;
  final List<Widget> hijos;
  final Future<void> Function()? alActualizar;
  final bool conVolver;
  const PantallaBase({super.key, this.titulo, required this.hijos, this.alActualizar, this.conVolver = false});

  @override
  Widget build(BuildContext context) {
    final lista = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: hijos,
    );
    return Scaffold(
      appBar: titulo == null
          ? null
          : AppBar(
              title: Text(titulo!),
              leading: conVolver ? const BackButton() : null,
              automaticallyImplyLeading: conVolver,
            ),
      body: SafeArea(
        child: alActualizar == null ? lista : RefreshIndicator(onRefresh: alActualizar!, child: lista),
      ),
    );
  }
}

void mostrarAviso(BuildContext context, String mensaje) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(mensaje)));
}
