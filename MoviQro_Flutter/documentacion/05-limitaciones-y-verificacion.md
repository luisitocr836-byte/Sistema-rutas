# 05 · Limitaciones, verificación y discrepancias documentales

## Verificado (entorno de construcción: Linux, Node 22, PostgreSQL 16 + PostGIS 3.4)

| Comprobación | Resultado |
|---|---|
| `vitest run` (backend + núcleo TypeScript) | ver resultado en el README (se vuelve a ejecutar antes de entregar) |
| `tsc --noEmit` backend | ver README |
| `sql:probar` (7 grupos + idempotencia) | ver README; contra una **simulación local** de Supabase |
| Análisis sintáctico de todos los `.dart` (tree-sitter) | sin errores de sintaxis |

## NO verificado — importante

- **El código Dart NO se compiló ni se ejecutó.** El entorno de construcción no tiene Flutter ni Dart y no puede descargarlos. El análisis sintáctico solo detecta errores de gramática; **no** detecta errores de tipos, de nombres ni de API de los paquetes. Es probable que `flutter analyze` / `flutter run` muestren errores menores que habrá que corregir.
- **Las pruebas Dart (`app-flutter/test/`) están escritas pero NO se ejecutaron.** No se afirma que pasen.
- La app en teléfono o emulador (interfaz, mapa, gestos).
- La generación de `android/` con `flutter create` sobre el overlay incluido.
- Proyecto Supabase real: Realtime, Auth y RLS con JWT reales.
- Consultas reales a OSRM / Google Distance Matrix.
- **Ubicación en segundo plano**: implementada con el servicio en primer plano de `geolocator`, sin probar con pantalla bloqueada.
- Cualquier prueba de campo; no existe MAE real. iOS.
- Compatibilidad exacta de versiones de paquetes (`pubspec.yaml` usa rangos `^`; `pubspec.lock` no se incluye porque no se pudo generar).

## Datos

Rutas 38 y 39 incluidas son **demostrativas**. Los GeoJSON reales del Avance 1 no estaban disponibles; ver `datos-espaciales/LEEME.md`.

## Discrepancias detectadas en los documentos

1. El Avance 2 habla de condiciones reales de tráfico; **OSRM no tiene tráfico en vivo** (solo Google con `duration_in_traffic`).
2. El Avance 2 describe GPS en segundo plano como funcional; no se pudo comprobar aquí.
3. La cifra MAE < 1.3 min se apoya en 3 pruebas parciales; el propio plan prevé ≥ 100 recorridos.
4. El Avance 2 usa `porcentaje_de_error` y su ER `error_porcentual`; se adoptó `error_porcentual`.
5. El número de tablas entre documentos y encargo no se reconcilió de forma verificada; se implementaron las 6 del encargo más una de apoyo.
