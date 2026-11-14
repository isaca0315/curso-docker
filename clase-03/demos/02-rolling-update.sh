#!/usr/bin/env bash
# Actualiza la API a 3.1 y vuelve a 3.0 con rollout undo.
# Requiere la imagen tienda-api:3.0 ya cargada en el clúster.
set -euo pipefail

cd "$(dirname "$0")/../lab"

KUBECTL=${KUBECTL:-kubectl}
KIND=${KIND:-kind}

if ! $KUBECTL get deployment api -n tienda >/dev/null 2>&1; then
  echo "No existe deployment/api en el namespace tienda." >&2
  echo "Sigue la guía paso a paso antes de ejecutar esta demo." >&2
  exit 1
fi

if ! docker image inspect tienda-api:3.0 >/dev/null 2>&1; then
  echo "Falta la imagen tienda-api:3.0. Construye con:" >&2
  echo "  docker build -t tienda-api:3.0 ../../clase-02/lab/app" >&2
  exit 1
fi

echo "== Versión actual =="
$KUBECTL exec deploy/api -n tienda -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read().decode())"

echo
echo "== Etiquetando 3.0 como 3.1 y cargando en kind =="
docker tag tienda-api:3.0 tienda-api:3.1
$KIND load docker-image tienda-api:3.1 --name curso

echo
echo "== Desplegando 3.1 =="
$KUBECTL set image deployment/api api=tienda-api:3.1 -n tienda
$KUBECTL set env deployment/api APP_VERSION=3.1 -n tienda
$KUBECTL rollout status deployment/api -n tienda --timeout=120s
$KUBECTL exec deploy/api -n tienda -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read().decode())"

echo
echo "== Historial =="
$KUBECTL rollout history deployment/api -n tienda

echo
echo "== Volviendo a la revisión anterior =="
$KUBECTL rollout undo deployment/api -n tienda
$KUBECTL rollout status deployment/api -n tienda --timeout=120s
$KUBECTL exec deploy/api -n tienda -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read().decode())"

echo
echo "Con maxUnavailable: 0 y maxSurge: 1, Kubernetes crea un pod nuevo antes de retirar uno viejo."
