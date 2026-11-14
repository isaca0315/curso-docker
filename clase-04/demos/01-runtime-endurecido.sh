#!/usr/bin/env bash
# Muestra el endurecimiento en ejecución: usuario, sistema de archivos,
# capacidades y opciones de seguridad. Requiere el stack de la clase 4 arriba.
set -euo pipefail

cd "$(dirname "$0")/../lab"

if ! docker compose ps --status running --services | grep -qx api; then
  echo "El stack no está arrancado. Ejecuta: docker compose up -d" >&2
  exit 1
fi

echo "== Identidad del proceso =="
docker compose exec -T api id

echo
echo "== El sistema de archivos raíz es de solo lectura =="
docker compose exec -T api sh -c 'touch /app/prueba' 2>&1 || true
echo "En /tmp sí se puede escribir porque es un tmpfs:"
docker compose exec -T api sh -c 'touch /tmp/prueba && echo "tmp escribible"'

echo
echo "== Capacidades efectivas =="
docker compose exec -T api sh -c 'grep -E "Cap(Eff|Bnd)" /proc/self/status'

echo
echo "== Opciones del contenedor =="
docker inspect tienda-segura-api-1 --format \
  'readonly={{.HostConfig.ReadonlyRootfs}} user={{.Config.User}} capdrop={{.HostConfig.CapDrop}} security_opt={{.HostConfig.SecurityOpt}}'

echo
echo "== Red: la base no es alcanzable desde edge =="
docker network inspect tienda_segura_backend --format 'backend: {{range .Containers}}{{.Name}} {{end}}'
docker network inspect tienda_segura_edge --format 'edge:    {{range .Containers}}{{.Name}} {{end}}'

echo
echo "Sin CAP_DROP, un proceso comprometido conserva capacidades como CAP_NET_RAW."
echo "Con cap_drop ALL y no-new-privileges, el contenedor no puede elevar privilegios."
