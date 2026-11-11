import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/entorno.dart';
import '../config/tema.dart';
import '../core/core.dart';
import '../estado/datos_modelo.dart';
import '../servicios/transmisor_gps.dart';
import '../utilidades/formato.dart';
import '../widgets/comunes.dart';

const _intervalosS = [3, 4, 5, 10];

/// Modo conductor: transmisor GPS para unidades autorizadas.
class PantallaTransmisor extends StatefulWidget {
  const PantallaTransmisor({super.key});

  @override
  State<PantallaTransmisor> createState() => _PantallaTransmisorState();
}

class _PantallaTransmisorState extends State<PantallaTransmisor> {
  ModoTransmision _modo = ModoTransmision.real;
  int _intervaloS = _intervalosS.contains(Entorno.intervaloTransmisionS) ? Entorno.intervaloTransmisionS : 4;
  bool _segundoPlano = false;
  String? _numeroRutaDemo;
  EstadisticasTransmision _est = const EstadisticasTransmision();
  TransmisorGps? _tx;

  final _email = TextEditingController();
  final _clave = TextEditingController();
  bool _entrando = false;
  String? _errorAuth;
  ({int idUnidad, String numeroEconomico})? _autorizacion;

  SupabaseClient? get _db => Entorno.supabaseConfigurado ? Supabase.instance.client : null;

  @override
  void initState() {
    super.initState();
    if (_db?.auth.currentSession != null) _cargarAutorizacion();
  }

  @override
  void dispose() {
    _tx?.detener();
    _email.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _cargarAutorizacion() async {
    final db = _db;
    if (db == null) return;
    setState(() => _errorAuth = null);
    try {
      final data = await db.from('autorizaciones_transmision').select('id_unidad, unidades(numero_economico)').limit(1).maybeSingle();
      if (!mounted) return;
      if (data == null) {
        setState(() => _autorizacion = null);
        return;
      }
      final u = data['unidades'];
      final numEco = u is Map ? u['numero_economico'] : (u is List && u.isNotEmpty ? (u.first as Map)['numero_economico'] : null);
      final id = (data['id_unidad'] as num).toInt();
      setState(() => _autorizacion = (idUnidad: id, numeroEconomico: (numEco ?? '#$id').toString()));
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorAuth = 'No se pudo verificar la autorización de esta cuenta. Revisa tu conexión.';
          _autorizacion = null;
        });
      }
    }
  }

  Future<void> _iniciarSesion() async {
    final db = _db;
    if (db == null) return;
    setState(() {
      _entrando = true;
      _errorAuth = null;
    });
    try {
      await db.auth.signInWithPassword(email: _email.text.trim(), password: _clave.text);
      _clave.clear();
      await _cargarAutorizacion();
    } on AuthException {
      if (mounted) setState(() => _errorAuth = 'Correo o contraseña incorrectos.');
    } catch (e) {
      if (mounted) setState(() => _errorAuth = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await _detener();
    await _db?.auth.signOut();
    if (mounted) setState(() => _autorizacion = null);
  }

  bool get _activo => _est.estado == EstadoTransmision.activo || _est.estado == EstadoTransmision.iniciando;

  Future<void> _iniciar(DatosModelo datos) async {
    final db = _db;
    EnviarLote? enviar;
    var idUnidad = 1;

    if (_modo == ModoTransmision.real) {
      if (db != null) {
        if (db.auth.currentSession == null) {
          mostrarAviso(context, 'Inicia sesión con la cuenta de la unidad para transmitir.');
          return;
        }
        if (_autorizacion == null) {
          mostrarAviso(context, 'Esta cuenta no está autorizada para ninguna unidad.');
          return;
        }
        idUnidad = _autorizacion!.idUnidad;
        enviar = enviarASupabase(db);
      }
    }

    List<Coordenada>? traz;
    if (_modo == ModoTransmision.demostracion) {
      final rp = (_numeroRutaDemo != null ? datos.rutaPorNumero(_numeroRutaDemo!) : null) ?? (datos.rutas.isEmpty ? null : datos.rutas.first);
      traz = rp?.ruta.trazado;
    }

    final tx = TransmisorGps(
      idUnidad: idUnidad,
      intervalo: Duration(seconds: _intervaloS),
      modo: _modo,
      segundoPlano: _segundoPlano && _modo == ModoTransmision.real,
      trazadoDemo: traz,
      enviar: enviar,
      alCambiar: (s) {
        if (mounted) setState(() => _est = s);
      },
    );
    _tx = tx;
    await tx.iniciar();
  }

  Future<void> _detener() async {
    await _tx?.detener();
    _tx = null;
  }

  String _descripcion() {
    if (_modo == ModoTransmision.demostracion) {
      return 'Demostración: se simula el recorrido y las lecturas se muestran aquí, pero NO se envían al servidor (la política de seguridad solo admite posiciones reales). Para alimentar el servidor con datos simulados use el simulador GPS (carpeta simulador-gps).';
    }
    if (_db == null) return 'Supabase no está configurado: se captura el GPS del dispositivo pero no se transmite.';
    if (_db!.auth.currentSession == null) return 'Inicia sesión con la cuenta de la unidad para transmitir.';
    if (_autorizacion == null) return 'Esta cuenta no está autorizada para ninguna unidad. Un administrador debe vincularla (tabla autorizaciones_transmision).';
    return 'Se transmitirá la posición real de la unidad ${_autorizacion!.numeroEconomico} cada $_intervaloS s.';
  }

  @override
  Widget build(BuildContext context) {
    final datos = context.watch<DatosModelo>();
    final db = _db;
    final sesion = db?.auth.currentSession;
    final l = _est.ultimaLectura;

    return PantallaBase(
      titulo: 'Modo conductor',
      conVolver: true,
      hijos: [
        const Text('Transmisor GPS para unidades autorizadas. Captura latitud, longitud, velocidad y precisión, y las envía a la base de datos.', style: TextStyle(color: Colores.atenuado, fontSize: 13)),
        const SizedBox(height: 14),
        if (db != null) _Panel(titulo: 'Cuenta de la unidad', hijos: [
          if (sesion != null) ...[
            Text('Sesión: ${sesion.user.email ?? 'cuenta de la unidad'}'),
            const SizedBox(height: 4),
            Text(_autorizacion != null ? 'Unidad autorizada: ${_autorizacion!.numeroEconomico}' : 'Sin unidad autorizada', style: TextStyle(color: _autorizacion != null ? Colores.exito : Colores.alerta)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _cerrarSesion, child: const Text('Cerrar sesión')),
          ] else ...[
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Correo')),
            TextField(controller: _clave, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
            const SizedBox(height: 10),
            FilledButton(onPressed: _entrando ? null : _iniciarSesion, child: Text(_entrando ? 'Entrando…' : 'Iniciar sesión')),
          ],
          if (_errorAuth != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorAuth!, style: const TextStyle(color: Colores.error, fontSize: 12))),
        ]),
        _Panel(titulo: 'Configuración', hijos: [
          SegmentedButton<ModoTransmision>(
            segments: const [
              ButtonSegment(value: ModoTransmision.real, label: Text('GPS real')),
              ButtonSegment(value: ModoTransmision.demostracion, label: Text('Demostración')),
            ],
            selected: {_modo},
            onSelectionChanged: _activo ? null : (s) => setState(() => _modo = s.first),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Intervalo:'),
            for (final s in _intervalosS)
              ChoiceChip(label: Text('$s s'), selected: _intervaloS == s, onSelected: _activo ? null : (_) => setState(() => _intervaloS = s)),
          ]),
          if (_modo == ModoTransmision.demostracion && datos.rutas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final r in datos.rutas)
                ChoiceChip(
                  label: Text('Ruta ${r.ruta.numeroRuta}'),
                  selected: (_numeroRutaDemo ?? datos.rutas.first.ruta.numeroRuta) == r.ruta.numeroRuta,
                  onSelected: _activo ? null : (_) => setState(() => _numeroRutaDemo = r.ruta.numeroRuta),
                ),
            ]),
          ],
          if (_modo == ModoTransmision.real)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Segundo plano (experimental)'),
              subtitle: const Text('Servicio en primer plano de Android con notificación. No verificado en dispositivo.', style: TextStyle(fontSize: 11)),
              value: _segundoPlano,
              onChanged: _activo ? null : (v) => setState(() => _segundoPlano = v),
            ),
          const SizedBox(height: 6),
          Text(_descripcion(), style: const TextStyle(color: Colores.atenuado, fontSize: 12)),
          const SizedBox(height: 10),
          _activo
              ? FilledButton.tonal(onPressed: _detener, child: const Text('Detener transmisión'))
              : FilledButton(onPressed: () => _iniciar(datos), child: const Text('Iniciar transmisión')),
        ]),
        _Panel(titulo: 'Estado', hijos: [
          Row(children: [
            Expanded(child: Text(switch (_est.estado) {
              EstadoTransmision.detenido => 'Detenido',
              EstadoTransmision.iniciando => 'Iniciando…',
              EstadoTransmision.activo => 'Activo',
              EstadoTransmision.sinPermiso => 'Sin permiso de ubicación',
              EstadoTransmision.error => 'Error',
            }, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (_modo == ModoTransmision.demostracion) const InsigniaDato(TipoDato.demostracion),
          ]),
          const SizedBox(height: 6),
          Text('Enviadas: ${_est.enviadas} · En buffer: ${_est.pendientes}/${Parametros.maxBufferTransmision} · Descartadas: ${_est.descartadas}', style: const TextStyle(fontSize: 12)),
          if (_est.ultimaDuracionEnvioMs != null) Text('Último envío: ${_est.ultimaDuracionEnvioMs} ms', style: const TextStyle(fontSize: 12, color: Colores.atenuado)),
          if (l != null) ...[
            const SizedBox(height: 6),
            Text('Última lectura: ${l.latitud.toStringAsFixed(5)}, ${l.longitud.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12)),
            Text('Velocidad: ${formatearKmh(l.velocidadKmh)} · Precisión: ${l.precisionM == null ? 'Sin dato' : '${l.precisionM!.round()} m'} · ${l.origen == OrigenDato.real ? 'GPS real' : 'simulado'}', style: const TextStyle(fontSize: 12, color: Colores.atenuado)),
          ],
          if (_est.ultimoError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_est.ultimoError!, style: const TextStyle(color: Colores.error, fontSize: 12))),
        ]),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final String titulo;
  final List<Widget> hijos;
  const _Panel({required this.titulo, required this.hijos});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colores.panel, border: Border.all(color: Colores.linea), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          ...hijos,
        ]),
      );
}
