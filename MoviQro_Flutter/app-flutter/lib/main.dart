import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/entorno.dart';
import 'config/tema.dart';
import 'estado/datos_modelo.dart';
import 'pantallas/raiz.dart';
import 'servicios/datos_local.dart';
import 'servicios/datos_supabase.dart';
import 'servicios/favoritos.dart';
import 'servicios/proveedor_datos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ProveedorDatos proveedor;
  if (Entorno.supabaseConfigurado) {
    await Supabase.initialize(url: Entorno.supabaseUrl, anonKey: Entorno.supabaseAnonKey);
    proveedor = DatosSupabase(Supabase.instance.client);
  } else {
    // Sin credenciales: modo local de demostración (rutas incluidas + unidades SIMULADAS).
    proveedor = DatosLocal();
  }

  final favoritos = Favoritos();
  final datos = DatosModelo(proveedor);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Favoritos>.value(value: favoritos),
        ChangeNotifierProvider<DatosModelo>.value(value: datos),
      ],
      child: const MoviqroApp(),
    ),
  );

  // La carga ocurre después de pintar la primera pantalla (muestra "Cargando…").
  favoritos.cargar();
  datos.iniciar();
}

class MoviqroApp extends StatelessWidget {
  const MoviqroApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MoviQro',
        debugShowCheckedModeBanner: false,
        theme: temaMoviqro(),
        home: const PantallaRaiz(),
      );
}
