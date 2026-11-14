#!/usr/bin/env bash
# Demuestra qué hay debajo de `docker run`: procesos, namespaces, cgroups y capas.
# Uso: ./01-arquitectura.sh    (requiere la imagen tienda-api:optimized)
set -euo pipefail

IMG="${IMG:-tienda-api:optimized}"
NAME="tienda-demo-arq"
PORT="${PORT:-18090}"

if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  echo "Falta la imagen $IMG."
  echo "Constrúyela en clase-01/lab/app con: docker build -t $IMG ."
  exit 1
fi

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$NAME" -p "$PORT:8000" "$IMG" >/dev/null
sleep 3

echo "== 1. El contenedor es un proceso del host =="
PID=$(docker inspect -f '{{.State.Pid}}' "$NAME")
echo "PID del contenedor en el host: $PID"
ps -o pid,ppid,user,args -p "$PID" || true

echo
echo "== 2. El shim mantiene vivo el contenedor =="
ps -eo pid,ppid,args | grep '[c]ontainerd-shim' | head -3 || true

echo
echo "== 3. Namespaces vistos desde dentro =="
docker exec "$NAME" ls -l /proc/1/ns

echo
echo "== 4. Namespaces del mismo proceso vistos desde el host =="
ls -l "/proc/$PID/ns" 2>/dev/null || echo "(sin permisos: normal si no eres root; se ve igual desde dentro)"

echo
echo "== 5. cgroup del proceso =="
cat "/proc/$PID/cgroup" 2>/dev/null || echo "(sin permisos para leer /proc/$PID/cgroup)"

echo
echo "== 6. Procesos dentro del contenedor =="
docker top "$NAME"

echo
echo "== 7. La capa escribible es efímera =="
docker exec "$NAME" sh -c 'echo hola > /tmp/prueba.txt'
echo "docker diff (solo aparece lo escrito en ejecución):"
docker diff "$NAME"

echo
echo "== 8. Capas de la imagen (lo que viaja en la imagen) =="
docker history "$IMG" --format 'table {{.CreatedBy}}\t{{.Size}}' | head -12

echo
echo "Listo. Pregunta para el grupo: ¿dónde está el kernel de este contenedor?"
