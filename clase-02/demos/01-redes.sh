#!/usr/bin/env bash
# Demuestra el aislamiento entre las dos redes del stack de la clase 2.
# Requiere el stack arrancado: docker compose up -d (desde clase-02/lab).
set -euo pipefail

cd "$(dirname "$0")/../lab"

if ! docker compose ps --status running --services | grep -qx api; then
  echo "El stack no está arrancado. Ejecuta: docker compose up -d" >&2
  exit 1
fi

echo "== Contenedores por red =="
echo -n "backend:  "
docker network inspect tienda_backend --format '{{range .Containers}}{{.Name}} {{end}}'
echo -n "frontend: "
docker network inspect tienda_frontend --format '{{range .Containers}}{{.Name}} {{end}}'

echo
echo "== DNS desde la API (backend) =="
docker compose exec -T api getent hosts db

echo
echo "== DNS desde el proxy (frontend) =="
docker compose exec -T proxy sh -c 'getent hosts db || echo "db no existe en frontend"'

echo
echo "== Puerto 5432 desde netshoot en backend =="
docker run --rm --network tienda_backend nicolaka/netshoot \
  sh -c 'nc -z -w2 db 5432 && echo "db:5432 abierto"'

echo
echo "== Puerto 5432 desde netshoot en frontend =="
docker run --rm --network tienda_frontend nicolaka/netshoot \
  sh -c 'nc -z -w2 db 5432 || echo "db inalcanzable desde frontend"'

echo
echo "== localhost contra db, desde la API =="
docker compose exec -T api python - <<'PY'
import socket
for host in ("localhost", "db"):
    try:
        socket.create_connection((host, 5432), 2)
        print(f"{host}: conecta")
    except Exception as exc:
        print(f"{host}: ERROR: {exc}")
PY

echo
echo "== Puertos publicados =="
docker compose ps --format 'table {{.Name}}\t{{.Ports}}'
