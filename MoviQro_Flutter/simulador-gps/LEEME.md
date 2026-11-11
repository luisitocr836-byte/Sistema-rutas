# Simulador GPS

Desplaza una unidad **demostrativa** por una ruta piloto. Cada posición se marca `origen_dato = 'simulado'`
(nunca se mezcla con datos reales; las estimaciones derivadas se marcan `es_simulado = true` y se excluyen del MAE).

La implementación está en `backend/scripts/simular.ts` (reutiliza sus dependencias); `simulador-gps/simular.ts` es un lanzador.

```bash
cd backend && npm install
# 1) Sin Supabase (modo seco): imprime posiciones y el ETA por trazado
npm run simulador -- --ruta=38 --seco --pasos=20 --velocidad=40 --aceleracion=10

# 2) Contra Supabase (requiere backend/.env con SUPABASE_SERVICE_ROLE_KEY y la unidad DEMO-R38-01 de la semilla 002)
npm run simulador -- --ruta=38 --velocidad=30 --intervalo=4 --bucle
#    en otra terminal, el worker calcula y guarda los ETA:
npm run worker
```

Opciones: `--ruta=<n>` · `--velocidad=<km/h>` · `--intervalo=<s>` · `--aceleracion=<factor>` · `--bucle` · `--pasos=<n>` · `--seco`.

⚠ Usa la clave `service_role`: ejecútelo solo en un equipo de confianza, nunca en la app ni en un teléfono.
