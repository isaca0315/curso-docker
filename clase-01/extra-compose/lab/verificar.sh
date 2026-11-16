#!/usr/bin/env bash
# Comprueba el extra de Compose de la clase 1. Deja el entorno limpio al salir.
set -euo pipefail
cd "$(dirname "$0")"

fail() { echo "FALLO: $*" >&2; exit 1; }
cleanup() { docker compose down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== 1. Configuración válida =="
docker compose config --quiet

echo "== 2. Arranque y endpoints =="
docker compose up -d --wait
api_port=$(docker compose port api 8000 | cut -d: -f2)
proxy_port=$(docker compose port proxy 80 | cut -d: -f2)
curl -fsS "http://localhost:${api_port}/healthz" | grep -q '"ok"' \
  || fail "la API no responde"
curl -fsS "http://localhost:${proxy_port}/productos" | grep -q '"productos"' \
  || fail "el proxy no llega a la API"

echo "== 3. Límites y logs =="
api_id=$(docker compose ps -q api)
[ "$(docker inspect -f '{{.HostConfig.Memory}}' "$api_id")" = "134217728" ] \
  || fail "el límite de memoria no es 128 MiB"
[ "$(docker inspect -f '{{.HostConfig.NanoCpus}}' "$api_id")" = "500000000" ] \
  || fail "el límite de CPU no es 0,5"
[ "$(docker inspect -f '{{index .HostConfig.LogConfig.Config "max-size"}}' "$api_id")" = "10m" ] \
  || fail "la rotación de logs no está aplicada"

echo "== 4. Logs y exec =="
docker compose logs --tail=1 api >/dev/null
docker compose exec -T api id | grep -q 'uid=10001' \
  || fail "la API no corre con el usuario 10001"

echo "OK: compose válido, stack sano, proxy, límites, logs y usuario."
