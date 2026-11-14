#!/usr/bin/env bash
# Apunta la readiness a una ruta inexistente y observa cómo los pods salen
# del Service sin reiniciarse. Al final restaura la ruta.
set -euo pipefail

cd "$(dirname "$0")/../lab"

KUBECTL=${KUBECTL:-kubectl}

if ! $KUBECTL get deployment api -n tienda >/dev/null 2>&1; then
  echo "No existe deployment/api en el namespace tienda." >&2
  echo "Sigue la guía paso a paso antes de ejecutar esta demo." >&2
  exit 1
fi

echo "== Endpoints antes del cambio =="
$KUBECTL get endpoints api -n tienda

echo
echo "== Rompiendo la readiness (ruta /noexiste) =="
$KUBECTL patch deployment api -n tienda --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/noexiste"}]'

sleep 25

echo
echo "== Pods: los nuevos quedan 0/1 y siguen Running =="
$KUBECTL get pods -n tienda -l app=api

echo
echo "== Endpoints: solo los pods sanos reciben tráfico =="
$KUBECTL get endpoints api -n tienda

echo
echo "== Restaurando la readiness =="
$KUBECTL patch deployment api -n tienda --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/readyz"}]'
$KUBECTL rollout status deployment/api -n tienda --timeout=120s

echo
echo "Readiness retira del tráfico sin matar el proceso. Liveness sí reinicia."
