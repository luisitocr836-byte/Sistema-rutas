# 01 · Análisis de requisitos

Fuente: especificación del encargo, Avance 1 (PDF), Avance 2 (DOCX) y prototipo HTML. Estado: **implementado** salvo lo marcado como pendiente/no verificado (ver `05-limitaciones-y-verificacion.md`).

## Requisitos funcionales

| ID | Requisito | Implementación (`app-flutter/lib/`) |
|---|---|---|
| RF-01 | Listar y buscar rutas | `pantallas/rutas.dart`, `pantallas/inicio.dart` |
| RF-02 | Detalle de ruta con paradas y mapa | `pantallas/detalle_ruta.dart` |
| RF-03 | Mapa con polilíneas, paradas y unidades | `pantallas/mapa.dart`, `widgets/mapa_ruta.dart` (google_maps_flutter) |
| RF-04 | Seguimiento de unidad con ETA a la siguiente parada | `pantallas/seguimiento.dart`, `widgets/panel_seguimiento.dart` + worker |
| RF-05 | Favoritos persistentes | `servicios/favoritos.dart` (shared_preferences) |
| RF-06 | Rutas cercanas con permiso explícito de ubicación | `pantallas/rutas.dart` (geolocator; cálculo con `proyectarEnRuta`) |
| RF-07 | Incidencias viales | `pantallas/incidencias.dart` |
| RF-08 | Transmisor GPS configurable (buffer, validación, demo, segundo plano) | `servicios/transmisor_gps.dart`, `pantallas/transmisor.dart` |
| RF-09 | ETA con distancia vial, velocidad, unidad detenida, registro antiguo, respaldo | `core/eta.dart` (app/demo) y `backend/src/servicioEta.ts` (worker) |
| RF-10 | Registro de estimaciones, tiempo real observado, error absoluto y MAE | `estimaciones_eta`, `fn_registrar_llegada`, `fn_mae`, `core/mae.dart` |
| RF-11 | Etiquetar datos reales / estimados / demostración | `widgets/comunes.dart` → `InsigniaDato` |
| RF-12 | Estados de carga, error y sin conexión | `widgets/comunes.dart`, `widgets/banner_conexion.dart` |
| RF-13 | Importar GeoJSON reales | `backend/scripts/importar-geojson.ts` |

## Requisitos no funcionales

- **Seguridad**: sin credenciales en el código; `service_role` solo en servidor; RLS en todas las tablas.
- **Integridad espacial**: SRID 4326, orden (lon, lat), índices GiST.
- **Honestidad de datos**: sin ETA aleatorio; sin datos simulados presentados como reales; estados explícitos cuando faltan datos.
- **Reproducibilidad**: migraciones ordenadas e idempotentes; semillas identificadas como demostrativas.
- **Pruebas**: automatizadas para el núcleo (Dart y TypeScript), servicios y SQL.
- **Plataforma**: Android (Android Studio, Flutter, Kotlin para la capa nativa).

## Fuera de alcance / no justificado por los documentos

Tráfico en vivo con OSRM, predicción histórica, notificaciones push, iOS, pagos, cuentas de ciudadanos.
