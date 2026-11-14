#!/usr/bin/env bash
# Ejecuta los gates de CI sobre la imagen endurecida y muestra un caso que falla.
set -euo pipefail

cd "$(dirname "$0")/../lab"

echo "== Caso correcto: tienda-api:4.0 =="
./ci/verificar-imagen.sh tienda-api:4.0

echo
echo "== Caso incorrecto: python:3.12-slim (arranca como root) =="
if ./ci/verificar-imagen.sh python:3.12-slim; then
  echo "Esto no debería pasar: la imagen base no declara usuario." >&2
  exit 1
else
  echo "El pipeline se detiene antes de publicar la imagen."
fi

echo
echo "== Caso incorrecto: límite de tamaño muy bajo =="
MAX_MB=50 ./ci/verificar-imagen.sh tienda-api:4.0 || true

echo
echo "Los gates de usuario y tamaño son deterministas: no dependen de la base de CVEs."
echo "Trivy se ejecuta como informe y, si se activa TRIVY_GATE=1, solo bloquea CRITICAL corregibles."
