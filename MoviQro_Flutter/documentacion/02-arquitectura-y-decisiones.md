# 02 · Arquitectura y decisiones técnicas

## Componentes

1. **App Android (Flutter/Dart; capa nativa Kotlin)** en `app-flutter/`: lee catálogos y se suscribe a Realtime; muestra el ETA ya calculado. Acceso a datos intercambiable (`ProveedorDatos`): *Supabase* o *local de demostración*.
2. **Supabase**: PostgreSQL 16 + PostGIS, RLS, Realtime, Auth (`backend-sql/`).
3. **Worker ETA (Node/TypeScript)** en `backend/`: se suscribe a INSERT de `coordenadas_log`, ejecuta `ServicioEta.procesarUnidad`, guarda en `estimaciones_eta` y registra llegadas.
4. **Simulador GPS (Node)**: inserta posiciones marcadas `origen_dato='simulado'` con `service_role`.
5. **Núcleo ETA en dos lenguajes**: `app-flutter/lib/core/` (Dart, usado por la app en modo demostración, por el transmisor y por las pruebas Dart) y `backend/core/` (TypeScript, usado por el worker, el simulador y las pruebas Vitest). Son **portes manuales** de la misma lógica; ver riesgo abajo.

## Flujo del ETA

lectura válida más reciente → descartar inválida/antigua (>60 s) → siguiente parada (proyección sobre el trazado, tolerancia 25 m) → distancia/duración del proveedor (OSRM/Google) → mezcla con velocidad suavizada (EMA α=0.4): `eta = w·vial + (1−w)·vehículo`, `w=0.6` por defecto; unidad detenida → solo duración vial; sin proveedor → `respaldo_ruta` (distancia por trazado ÷ velocidad suavizada o 15 km/h configurable). La fuente se registra en `fuente_calculo`.

## Decisiones

| Decisión | Motivo | Consecuencia |
|---|---|---|
| Flutter (Dart) + Kotlin | Pedido por el usuario para Android Studio; los documentos admitían RN o Flutter | Sin Flutter SDK no se pudo compilar aquí |
| Subcarpeta `android/` solo con overlay | El andamiaje de Gradle depende de la versión de Flutter; se genera con `flutter create` | Ejecutar `preparar_android` una vez |
| Configuración con `--dart-define-from-file` | Sin `.env` empaquetado como asset; sin secretos en el repo | `config/app.json` local e ignorado por git |
| OSRM por defecto (worker) | Sin cuota de pago | **Sin tráfico en vivo**; el público es solo demo |
| ETA en worker de servidor | Protege claves, centraliza registro para validar | Requiere un proceso en ejecución |
| Núcleo duplicado (Dart + TS) | La app no puede ejecutar TS y el worker no puede ejecutar Dart sin SDK | **Riesgo de divergencia**: cualquier cambio de lógica debe hacerse en ambos y probarse en ambos |
| Segundo plano con servicio en primer plano de `geolocator` | Evita código nativo propio | No verificado en dispositivo |
| Tabla extra `autorizaciones_transmision` | Autorizar conductores sin secretos en `unidades` | 6 tablas pedidas + 1 de apoyo |
| Columnas extra (`origen_dato`, `fuente_datos`, `fuente_calculo`, `latencia_transmision_ms`) | Trazabilidad real/simulado/demo | Filtros en MAE y en la interfaz |
| GeoJSON como fuente única | Genera semilla SQL, datos locales Dart y TS | `npm run datos:generar` |
| `error_porcentual` (no `porcentaje_de_error`) | Coincide con el ER del Avance 2 | Nombre unificado |
