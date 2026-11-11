#!/usr/bin/env bash
# Prueba migraciones, RLS, semillas y funciones en un PostgreSQL local con PostGIS (clúster temporal).
# Requisitos: PostgreSQL (initdb/pg_ctl/psql) y PostGIS instalados; ejecutar con permisos para
# `su postgres` (root) o como un usuario que pueda ejecutar initdb. NO toca Supabase.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../../.." && pwd)"
PGBIN="$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)"
DIR="${PG_TMP_DIR:-/tmp/moviqro_pg_test}"
PORT="${PG_TEST_PORT:-54329}"

run_pg() { if [ "$(id -u)" = "0" ]; then su postgres -c "$*"; else bash -c "$*"; fi; }

rm -rf "$DIR"; mkdir -p "$DIR"
[ "$(id -u)" = "0" ] && chown postgres:postgres "$DIR"
run_pg "$PGBIN/initdb -D $DIR/data -A trust >/dev/null"
run_pg "$PGBIN/pg_ctl -D $DIR/data -o '-p $PORT -k $DIR' -l $DIR/log -w start >/dev/null"
trap 'run_pg "$PGBIN/pg_ctl -D $DIR/data -m immediate stop >/dev/null" || true' EXIT

PSQL="psql -h $DIR -p $PORT -U postgres -v ON_ERROR_STOP=1 -q"
run_pg "$PSQL -d postgres -c 'create database moviqro_test'"
for f in "$AQUI/stub_supabase.sql" \
         "$RAIZ"/backend-sql/migrations/*.sql \
         "$RAIZ"/backend-sql/policies/*.sql \
         "$RAIZ"/backend-sql/seeds/*.sql \
         "$AQUI/pruebas.sql"; do
  echo ">> $(basename "$f")"
  run_pg "$PSQL -d moviqro_test -f '$f'" 2>&1 || { echo "ERROR en $f"; exit 1; }
done
# Reproducibilidad: segunda ejecución de migraciones y semillas (idempotencia)
for f in "$RAIZ"/backend-sql/migrations/*.sql "$RAIZ"/backend-sql/seeds/*.sql; do
  run_pg "$PSQL -d moviqro_test -f '$f'" >/dev/null 2>&1 || { echo "ERROR: $(basename "$f") no es idempotente"; exit 1; }
done
echo ">> Idempotencia OK (migraciones y semillas se ejecutaron por segunda vez sin error)"
