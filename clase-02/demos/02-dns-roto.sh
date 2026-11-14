#!/usr/bin/env bash
# Rompe un nombre a propósito y compara los dos errores de red más comunes.
# Requiere el stack arrancado: docker compose up -d (desde clase-02/lab).
set -euo pipefail

cd "$(dirname "$0")/../lab"

if ! docker compose ps --status running --services | grep -qx api; then
  echo "El stack no está arrancado. Ejecuta: docker compose up -d" >&2
  exit 1
fi

echo "== Un nombre correcto y uno inexistente =="
docker run --rm -i --network tienda_backend tienda-api:2.0 python - <<'PY'
import socket
for host in ("db", "basededatos"):
    try:
        print(f"{host}: {socket.gethostbyname(host)}")
    except Exception as exc:
        print(f"{host}: ERROR: {exc}")
PY

echo
echo "== localhost no es el contenedor de al lado =="
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
echo "Claves:"
echo "  Un error de resolución ocurre antes de conectar: el nombre no existe."
echo "  Connection refused        -> el nombre resuelve, pero nadie escucha en ese puerto."
echo "  localhost siempre apunta al propio contenedor."
