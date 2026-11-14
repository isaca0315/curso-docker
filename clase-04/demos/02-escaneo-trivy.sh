#!/usr/bin/env bash
# Escanea la imagen con Trivy y genera un SBOM. El escaneo informa;
# el gate del pipeline es el script de ci/, no la lista de CVEs del día.
set -euo pipefail

cd "$(dirname "$0")/../lab"

IMAGE=${1:-tienda-api:4.0}

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "La imagen $IMAGE no existe. Construye con: docker compose build api" >&2
  exit 1
fi

if ! command -v trivy >/dev/null 2>&1; then
  echo "Trivy no está instalado. Instálalo con:" >&2
  echo "  curl -sSL https://get.trivy.dev | sh -s -- -b /usr/local/bin" >&2
  echo "El resto del laboratorio funciona sin él; el escaneo es un informe." >&2
  exit 0
fi

echo "== CVEs HIGH y CRITICAL con corrección disponible =="
trivy image --quiet --scanners vuln --severity HIGH,CRITICAL \
  --ignore-unfixed "$IMAGE" || true

echo
echo "== SBOM en formato CycloneDX =="
trivy image --quiet --format cyclonedx --output /tmp/tienda-api-sbom.json "$IMAGE"
echo "Generado /tmp/tienda-api-sbom.json"
du -h /tmp/tienda-api-sbom.json

echo
echo "Lee el resultado por capas:"
echo "  - Un CVE en la base Debian se corrige actualizando la imagen base."
echo "  - Un CVE en una dependencia de Python se corrige subiendo su versión."
echo "  - Un CVE sin corrección (unfixed) no se arregla con un rebuild."
echo "No bloquees el pipeline con cualquier CVE: fija un umbral y revísalo."
