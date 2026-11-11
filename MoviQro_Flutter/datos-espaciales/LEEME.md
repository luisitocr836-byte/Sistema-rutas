# Datos espaciales de las rutas piloto

> ⚠ **`ruta_38.geojson` y `ruta_39.geojson` contienen geometría DEMOSTRATIVA.**
> Los GeoJSON digitalizados en el Avance 1 no estaban disponibles al construir este proyecto, por lo que
> el trazado y las paradas son aproximados e ilustrativos (declarado en `fuente_datos: "demostracion"`).
> **No son recorridos oficiales.** La app los rotula "Demostración".

## Cómo sustituirlos por los reales

1. Reemplace cada archivo respetando el formato (FeatureCollection, coordenadas `[longitud, latitud]`, WGS84):

   - **1 Feature `LineString`** con `properties`:
     `tipo: "ruta"`, `numero_ruta`, `nombre`, `origen`, `destino`, `fuente_datos`
     (**obligatoria**: `oficial` | `levantamiento_equipo` | `demostracion`), y opcionales
     `color_hex` (`#RRGGBB`), `horario_inicio`, `horario_fin`, `frecuencia_promedio_min` (entero o `null`).
   - **N Features `Point`** (paradas) con `properties`:
     `tipo: "parada"`, `orden_secuencia` (entero ≥ 1, único), `nombre`, y opcionales `referencia_vial`, `es_nodo_transferencia`.

   El trazado debe seguir el sentido del recorrido (origen → destino) y las paradas deben quedar sobre/junto a él.
2. Para marcar los datos como propios, ponga `fuente_datos` en `levantamiento_equipo` (o `oficial` si procede).
3. Cargue en Supabase, con **una** de estas vías:
   - `cd backend && npm run datos:importar` (usa la clave de servicio del `.env`), **o**
   - `cd backend && npm run datos:generar` y ejecute `backend-sql/seeds/001_rutas_y_paradas.sql` en el SQL Editor.
4. `npm run datos:generar` también regenera los datos locales de la app (`app-flutter/lib/datos/rutas_locales.dart` y `backend/core/rutasLocales.ts`).

Validaciones al leer: coordenadas válidas (rango, no `(0,0)`, no invertidas), ≥ 2 vértices, órdenes de parada únicos y `fuente_datos` explícita.
