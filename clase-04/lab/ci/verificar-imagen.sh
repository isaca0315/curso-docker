#!/usr/bin/env bash
# Gates deterministas de la imagen de la clase 4.
# Uso: ./verificar-imagen.sh [imagen]
#   MAX_MB=300           tamaño máximo en MiB
#   TRIVY_GATE=1         falla si Trivy encuentra CRITICAL corregibles
#
# Los gates de usuario y tamaño no dependen de la base de datos de CVEs,
# así que el pipeline no se rompe porque aparezca un CVE nuevo en Debian.
set -uo pipefail

IMAGE=${1:-tienda-api:4.0}
MAX_MB=${MAX_MB:-300}
FALLOS=0

ok() { printf '  OK    %s\n' "$1"; }
ko() { printf '  FALLO %s\n' "$1"; FALLOS=$((FALLOS + 1)); }
info() { printf '  INFO  %s\n' "$1"; }

if ! command -v docker >/dev/null 2>&1; then
  echo "docker no está en el PATH" >&2
  exit 2
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "La imagen $IMAGE no existe. Construye con: docker compose build api" >&2
  exit 2
fi

echo "== Gates de $IMAGE =="

# 1. El proceso arranca sin privilegios.
UID_REAL=$(docker run --rm --entrypoint python "$IMAGE" -c 'import os; print(os.getuid())' 2>/dev/null || echo error)
case "$UID_REAL" in
  0) ko "el proceso arranca como root (uid=0)" ;;
  error|"") ko "no se pudo comprobar el uid de arranque" ;;
  *) ok "el proceso arranca con uid=$UID_REAL" ;;
esac

# 2. La imagen declara un usuario distinto de root.
USUARIO=$(docker image inspect -f '{{.Config.User}}' "$IMAGE")
case "$USUARIO" in
  ""|root|0|0:0) ko "Config.User está vacío o es root" ;;
  *) ok "Config.User=$USUARIO" ;;
esac

# 3. Tamaño acotado.
BYTES=$(docker image inspect -f '{{.Size}}' "$IMAGE")
MB=$((BYTES / 1024 / 1024))
if [ "$MB" -le "$MAX_MB" ]; then
  ok "tamaño ${MB} MiB (máximo ${MAX_MB} MiB)"
else
  ko "tamaño ${MB} MiB supera el máximo de ${MAX_MB} MiB"
fi

# 4. Trivy: informe por defecto, gate opcional.
if command -v trivy >/dev/null 2>&1; then
  if [ "${TRIVY_GATE:-0}" = "1" ]; then
    if trivy image --quiet --scanners vuln --severity CRITICAL \
        --ignore-unfixed --exit-code 1 "$IMAGE" >/dev/null 2>&1; then
      ok "Trivy no encuentra CRITICAL corregibles"
    else
      ko "Trivy encuentra CRITICAL corregibles"
    fi
  else
    info "Trivy en modo informe (sin bloquear). Activa el gate con TRIVY_GATE=1"
    trivy image --quiet --scanners vuln --severity HIGH,CRITICAL \
      --ignore-unfixed "$IMAGE" 2>/dev/null | tail -12 || true
  fi
else
  info "Trivy no está instalado; se omite el escaneo"
fi

echo
if [ "$FALLOS" -eq 0 ]; then
  echo "Resultado: imagen apta"
  exit 0
fi
echo "Resultado: $FALLOS gate(s) fallidos"
exit 1
