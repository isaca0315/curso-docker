#!/usr/bin/env bash
# Compara tamaño, capas y caché entre la imagen ingenua y la optimizada.
# Uso: ./03-capas-cache.sh
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/../lab/app" && pwd)"
cd "$APP_DIR"

if ! docker image inspect tienda-api:naive >/dev/null 2>&1; then
  echo "Construyendo imagen ingenua..."
  docker build -q -f Dockerfile.naive -t tienda-api:naive . >/dev/null
fi
if ! docker image inspect tienda-api:optimized >/dev/null 2>&1; then
  echo "Construyendo imagen optimizada..."
  docker build -q -t tienda-api:optimized . >/dev/null
fi

echo "== 1. Tamaño de las imágenes =="
docker images tienda-api --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'

echo
echo "== 2. Dónde se va el peso (imagen ingenua) =="
docker history tienda-api:naive --format 'table {{.CreatedBy}}\t{{.Size}}' | head -10

echo
echo "== 3. Imagen optimizada: capas propias pequeñas =="
docker history tienda-api:optimized --format 'table {{.CreatedBy}}\t{{.Size}}' | head -10

echo
echo "== 4. Caché: cambiamos UNA línea de app.py =="
cp app.py /tmp/tienda-app.py.bak
restore() { cp /tmp/tienda-app.py.bak app.py; }
trap restore EXIT
printf '\n# cambio para invalidar la capa de código\n' >> app.py

echo
echo "--- Ingenua: COPY . . va antes de pip install ---"
docker build --progress=plain -f Dockerfile.naive -t tienda-api:naive . 2>&1 \
  | grep -E 'CACHED|\[4/4\] RUN pip install|COPY \. \.' | tail -6

echo
echo "--- Optimizada: dependencias en capa aparte ---"
docker build --progress=plain -t tienda-api:optimized . 2>&1 \
  | grep -E 'CACHED|\[builder .*RUN python -m venv|COPY app.py' | tail -8

echo
echo "Conclusión: en la ingenua se reinstalan dependencias por un cambio de código;"
echo "en la optimizada solo se recopia app.py."
