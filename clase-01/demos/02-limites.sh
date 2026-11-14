#!/usr/bin/env bash
# Límites de CPU/memoria, cgroups v2 y OOM kill.
# Uso: ./02-limites.sh    (requiere la imagen tienda-api:optimized)
set -euo pipefail

IMG="${IMG:-tienda-api:optimized}"
PORT="${PORT:-18091}"
NAME="tienda-demo-lim"
OOM="tienda-demo-oom"
CPU="tienda-demo-cpu"

if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  echo "Falta la imagen $IMG. Constrúyela en clase-01/lab/app: docker build -t $IMG ."
  exit 1
fi

cleanup() { docker rm -f "$NAME" "$OOM" "$CPU" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== 1. Contenedor con 0,5 CPU y 128 MiB =="
docker run -d --name "$NAME" --memory 128m --cpus 0.5 -p "$PORT:8000" "$IMG" >/dev/null
sleep 3
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' "$NAME"

echo
echo "== 2. Los límites se ven en el cgroup v2 =="
echo -n "memory.max: "; docker exec "$NAME" cat /sys/fs/cgroup/memory.max
echo -n "cpu.max:    "; docker exec "$NAME" cat /sys/fs/cgroup/cpu.max
echo "(cpu.max = cuota periodo; 50000 100000 equivale a medio núcleo)"

echo
echo "== 3. OOM: 200 MiB en un contenedor limitado a 64 MiB =="
docker run -d --name "$OOM" --memory 64m "$IMG" python -c 'a=bytearray(200*1024*1024)
for i in range(0, len(a), 4096): a[i] = 1' >/dev/null
sleep 3
for _ in 1 2 3 4 5; do
  [ "$(docker inspect -f '{{.State.OOMKilled}}' "$OOM")" = "true" ] && break
  sleep 1
done
docker inspect --format 'OOMKilled={{.State.OOMKilled}} exit={{.State.ExitCode}} (137 = SIGKILL)' "$OOM"
echo "Sin --memory, ese proceso habría presionado la memoria de todo el host."

echo
echo "== 4. CPU: bucle infinito con medio núcleo =="
docker run -d --name "$CPU" --cpus 0.5 "$IMG" python -c 'while True: pass' >/dev/null
sleep 5
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}' "$CPU"
echo "(debe rondar el 50 %)"

echo
echo "Limpiando contenedores de la demo..."
