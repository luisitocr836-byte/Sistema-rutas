# MoviQro · versión Android (Flutter + Kotlin)

Aplicación para consultar el **transporte público urbano de San Juan del Río, Querétaro**: rutas, paradas georreferenciadas, posición aproximada de las unidades y **tiempo estimado de llegada (ETA)**, con las rutas piloto **38 y 39**. Esta versión está hecha para abrirse en **Android Studio**: app en **Flutter (Dart)** con la capa nativa de Android en **Kotlin**, y backend en **Supabase/PostgreSQL/PostGIS**.

> ⚠ **Leer primero – estado real del proyecto**
> - **El código Dart de la app NO se pudo compilar ni ejecutar** en el entorno donde se generó (no hay Flutter/Dart ni se pueden descargar). Solo se comprobó que la sintaxis es válida. Al abrirlo por primera vez es posible que `flutter analyze` muestre errores menores de tipos o de API que habrá que corregir. **Las pruebas Dart están escritas pero no se ejecutaron.**
> - Los **GeoJSON reales de las rutas 38 y 39 no estaban disponibles**: se incluye geometría **demostrativa** (no oficial), rotulada "Demostración". Ver [`datos-espaciales/LEEME.md`](datos-espaciales/LEEME.md).
> - **No hay resultados de campo ni MAE verificado.** Ver [`documentacion/04-validacion-eta.md`](documentacion/04-validacion-eta.md).
> - Detalle de lo verificado y lo pendiente: [`documentacion/05-limitaciones-y-verificacion.md`](documentacion/05-limitaciones-y-verificacion.md).

## Estructura

| Carpeta | Contenido |
|---|---|
| `app-flutter/` | **Proyecto Flutter** (abrir esta carpeta en Android Studio). `lib/core/` = núcleo ETA en Dart; `lib/servicios/`, `lib/pantallas/`, `lib/widgets/`; `android/` = manifest y `MainActivity.kt` (Kotlin); `test/` = pruebas Dart. |
| `backend/` | Worker ETA (Node/TypeScript), importador de GeoJSON, reporte de MAE, simulador y pruebas Vitest. `backend/core/` = núcleo ETA en TypeScript. |
| `backend-sql/` | Migraciones (6 tablas + 1 de apoyo, índices GiST, triggers, funciones), políticas RLS y semillas. |
| `datos-espaciales/` | `ruta_38.geojson`, `ruta_39.geojson` (**demostrativos**): fuente única de verdad. |
| `simulador-gps/` | Lanzador del simulador de unidad. |
| `documentacion/` | Requisitos, arquitectura, modelo de datos, validación y limitaciones. |

## Funciones de la app

Inicio con buscador y favoritas · exploración y **búsqueda** de rutas (filtros Todas / Favoritas / **Cerca de ti**, con permiso de ubicación solicitado al tocar) · detalle con paradas y mapa · **mapa** nativo (Google Maps) con polilíneas, paradas y unidades · **seguimiento** con ETA a la siguiente parada (Realtime) · **favoritos** persistentes · incidencias viales · **modo conductor** (transmisor GPS real o demostración, buffer de 20 posiciones, segundo plano experimental) · insignias **GPS real / Estimado / Demostración** · estados de carga, error y sin conexión.

Sin credenciales de Supabase la app arranca en **modo local de demostración**: rutas incluidas y unidades **simuladas**, siempre etiquetadas "Demostración".

## Requisitos

- **Android Studio** (con los plugins **Flutter** y **Dart**) y el **SDK de Flutter** (canal stable, versión que incluya Dart ≥ 3.6; p. ej. Flutter 3.27 o superior). Verifique con `flutter doctor`.
- Un emulador o un teléfono Android con depuración USB.
- **Node.js ^22.13 o ^24.3** (solo para el backend, el worker, el simulador y las pruebas TypeScript).
- Cuenta de **Supabase** (plan gratuito sirve) para el modo con base de datos.
- Una **clave de Google Maps SDK for Android** (Google Cloud Console) para ver el mapa.

## 1. Preparar el proyecto Flutter (una sola vez)

La carpeta `app-flutter/android/` solo trae el manifest y `MainActivity.kt`; los archivos de Gradle dependen de su versión de Flutter y se generan así:

```bat
:: Windows
cd app-flutter
preparar_android.bat
```
```bash
# Linux / macOS
cd app-flutter && ./preparar_android.sh
```

Equivale a `flutter create --platforms=android --org mx.moviqro --project-name moviqro -a kotlin .` y `flutter pub get`. No pisa los archivos existentes. En Android Studio: *File → Open → `app-flutter`*.

**Clave de Google Maps:** abra `app-flutter/android/app/src/main/AndroidManifest.xml` y sustituya `TU_CLAVE_DE_GOOGLE_MAPS` por su clave (restríngala por paquete `mx.moviqro.moviqro` y huella SHA-1). No la suba a un repositorio público.

## 2. Configurar Supabase (PostGIS, migraciones, RLS, Realtime)

En el **SQL Editor** de su proyecto, ejecute **en este orden** (cada archivo completo; son idempotentes):

| Orden | Archivo | Qué hace |
|---|---|---|
| 1 | `backend-sql/migrations/001_tablas.sql` | **Activa PostGIS** y crea las tablas |
| 2 | `backend-sql/migrations/002_indices.sql` | Índices, incluidos **GiST** |
| 3 | `backend-sql/migrations/003_funciones_y_triggers.sql` | Triggers de telemetría y funciones (`fn_siguiente_parada`, `fn_rutas_cercanas`, `fn_registrar_llegada`, `fn_mae`) |
| 4 | `backend-sql/migrations/004_vistas_y_realtime.sql` | Vistas GeoJSON para la app y publicación **Realtime** |
| 5 | `backend-sql/policies/010_rls.sql` | **RLS** y permisos |
| 6 | `backend-sql/seeds/001_rutas_y_paradas.sql` | Rutas 38/39 y paradas (**demostrativas**) |
| 7 | `backend-sql/seeds/002_unidades_e_incidencias_demo.sql` | Unidades e incidencia **demostrativas** |

Claves: *Settings → API*. La clave **anon/publishable** va en la app; la **service_role** solo en `backend/.env`.

**Autorizar un teléfono transmisor real:** cree un usuario en *Authentication → Users* y vincúlelo a una unidad:
```sql
insert into public.autorizaciones_transmision (id_unidad, auth_user_id)
select id_unidad, '<UUID-del-usuario>'::uuid from public.unidades where numero_economico = 'DEMO-R38-01';
```
Modelo de seguridad: lectura pública de catálogos; **inserción en `coordenadas_log` solo** para un usuario autenticado y autorizado, con `origen_dato = 'real'`; estimaciones y datos simulados solo con `service_role` (servidor).

## 3. Configurar y ejecutar la app

```bash
cd app-flutter
cp config/app.ejemplo.json config/app.json      # Windows: copy config\app.ejemplo.json config\app.json
# editar config/app.json: SUPABASE_URL y SUPABASE_ANON_KEY (públicas). Sin ellos → modo demostración.
flutter run --dart-define-from-file=config/app.json
```

En **Android Studio**: *Run → Edit Configurations → Additional run args* → `--dart-define-from-file=config/app.json`. `config/app.json` está en `.gitignore`. **Nunca ponga la clave `service_role` en la app.**

Para probar solo la demostración (sin Supabase) basta `flutter run`.

## 4. Worker ETA y simulador GPS (Node)

```bash
npm run instalar
cp .env.example backend/.env       # completar SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY (secretos)
npm run worker                     # Terminal A: calcula y guarda ETA al llegar posiciones
npm run simulador -- --ruta=38 --velocidad=30 --intervalo=4 --bucle     # Terminal B
```
Abra la pestaña **Seguimiento** de la app: verá la unidad "Demostración" y su ETA. Sin Supabase: `npm run simulador -- --ruta=38 --seco --pasos=20`.

`ETA_PROVIDER`: `osrm` (por defecto; el servidor público es solo demostración y **OSRM no incorpora tráfico en vivo**), `google` o `none`. Si el proveedor falla se usa un respaldo por distancia a lo largo del trazado y se **declara** (`fuente_calculo = respaldo_ruta`).

## 5. Modo conductor

*Inicio → Modo conductor*: inicie sesión con la cuenta autorizada, elija intervalo (3–10 s) y pulse **Iniciar transmisión**. Valida cada lectura, acumula hasta **20** en un buffer y las reenvía al recuperar conexión. **Demostración**: simula el recorrido en pantalla y **no** escribe en la base (la RLS solo admite posiciones reales). **Segundo plano**: servicio en primer plano de Android (`geolocator`) con notificación; **no verificado en dispositivo**; requiere conceder "Permitir siempre".

## 6. Pruebas

```bash
# Dart (requiere Flutter; NO ejecutadas al generar el proyecto)
cd app-flutter && flutter pub get && flutter test && flutter analyze

# TypeScript (backend/worker/núcleo TS) y SQL
npm test
npm run typecheck
cd backend && npm run sql:probar     # requiere PostgreSQL 16 + PostGIS locales
```

## Verificación realizada al generar este ZIP

| Comprobación | Resultado |
|---|---|
| `vitest run` (backend + núcleo TypeScript) | **96 de 96** pruebas pasan, 10 archivos |
| `tsc --noEmit` backend | Sin errores |
| Pruebas SQL en PostgreSQL 16 + PostGIS 3.4 (`sql:probar`) | 7 grupos pasan y la segunda ejecución de migraciones/semillas no falla (contra una simulación local de Supabase) |
| Simulador en modo seco | Ejecuta con ETA por trazado coherentes |
| Sintaxis de los 40+ archivos `.dart` (tree-sitter) | Sin errores de sintaxis |
| **Compilación Flutter, `flutter analyze`, `flutter test`** | **NO ejecutados** (sin SDK de Flutter) |
| App en emulador/teléfono, Supabase real, OSRM real, segundo plano | **NO verificados** |

## Solución de errores comunes

| Síntoma | Causa / solución |
|---|---|
| `flutter analyze` / compilación muestra errores | El código Dart no se pudo compilar al generarlo; corrija los mensajes (suelen ser imports o tipos) o repórtelos para ajustarlos. |
| `Unsupported operation`/falta `android/build.gradle` | No ejecutó `preparar_android` (paso 1). |
| Mapa en gris | Falta o es inválida la clave en `AndroidManifest.xml`, o no habilitó *Maps SDK for Android*. |
| La app dice "modo demostración" | No pasó `--dart-define-from-file=config/app.json` o los valores son de ejemplo. |
| `permission denied` / `row-level security` al transmitir | La cuenta no está en `autorizaciones_transmision`, o se insertó `origen_dato <> 'real'`. |
| Hay unidad pero no ETA | El **worker** no está corriendo, la lectura tiene más de 60 s, o no hay paradas pendientes. |
| `MAE: sin observaciones` | Aún no hay estimaciones con tiempo real de unidades **reales**; las simuladas se excluyen. |
| Segundo plano no funciona | Falta permiso "Permitir siempre" o notificaciones, o el fabricante restringe la batería de la app. |

## Licencia y datos

Proyecto académico. Los datos de rutas incluidos son **demostrativos**; no los use para planear viajes reales.
