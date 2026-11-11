# 04 · Procedimiento de validación del ETA

**Este proyecto no incluye resultados de campo ni un MAE verificado.** Solo la herramienta para obtenerlos.

## Cómo se obtiene el tiempo real observado

1. Una unidad **real** transmite posiciones (`origen_dato='real'`).
2. El worker guarda estimaciones hacia la siguiente parada.
3. Cuando la unidad entra al radio de 40 m de la parada objetivo, `fn_registrar_llegada` completa `tiempo_real_min`, `error_absoluto_min` y `error_porcentual` de las estimaciones pendientes.

Los registros sin tiempo real observado **no entran** al cálculo. Los simulados se excluyen salvo `--incluir-simulados`.

## Métricas

- **MAE** = promedio de |ETA − real| (min). **MAPE** y error máximo también se reportan.
- `npm run validacion:mae [-- --ruta=<id>]` (en `backend/`), o `select * from fn_mae(...)`.

## Criterios mínimos recomendados

- El Avance 2 prevé **≥ 100 recorridos reales**; con menos, el MAE no es concluyente (el reporte lo avisa).
- Usar una instancia OSRM propia; el servidor público no es adecuado para validar.
- Registrar por separado ETA por proveedor y por respaldo (`fuente_calculo`).
- El Avance 2 cita un MAE < 1.3 min con solo 3 pruebas parciales: no es evidencia estadística.
