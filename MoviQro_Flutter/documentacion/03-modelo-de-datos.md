# 03 · Modelo de datos y seguridad

Archivos: `backend-sql/migrations/001…004`, `policies/010_rls.sql`, `seeds/`. Todas las geometrías: **SRID 4326**, orden **(longitud, latitud)**, índices **GiST**.

## Tablas

| Tabla | Propósito |
|---|---|
| `rutas` | Catálogo; `trazado` LineString; `fuente_datos` (oficial / levantamiento_equipo / demostracion) |
| `paradas` | Puntos por ruta con `orden_secuencia` único por ruta |
| `unidades` | Vehículos; última posición/velocidad/hora actualizadas por trigger |
| `coordenadas_log` | Telemetría; `origen_dato` (real/simulado); latencia calculada por trigger |
| `estimaciones_eta` | ETA calculado, fuente, tiempo real observado, error absoluto y porcentual |
| `incidencias_viales` | Incidencias con ubicación y vigencia |
| `autorizaciones_transmision` | (apoyo) usuario Auth ↔ unidad autorizada |

## Funciones

`fn_siguiente_parada`, `fn_rutas_cercanas`, `fn_registrar_llegada` (solo `service_role`), `fn_mae` (excluye simulados por defecto) y triggers de telemetría.

## RLS

- SELECT público en catálogos; telemetría pública limitada a las últimas 24 h.
- INSERT en `coordenadas_log`: solo usuario autenticado autorizado para esa unidad, con `origen_dato='real'`.
- Estimaciones, datos simulados y llegadas: solo `service_role` (servidor).

## Nota sobre latencia

`latencia_transmision_ms = recibido_en − fecha_hora` depende de la sincronización del reloj del dispositivo; no es una medida validada.
