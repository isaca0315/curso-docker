#!/usr/bin/env bash
# Borra un pod de la API y muestra cómo el Deployment crea otro.
# Requiere el clúster de la clase 3 en marcha y el namespace tienda.
set -euo pipefail

cd "$(dirname "$0")/../lab"

KUBECTL=${KUBECTL:-kubectl}

if ! $KUBECTL get deployment api -n tienda >/dev/null 2>&1; then
  echo "No existe deployment/api en el namespace tienda." >&2
  echo "Sigue la guía paso a paso antes de ejecutar esta demo." >&2
  exit 1
fi

echo "== Estado de partida =="
$KUBECTL scale deployment/api -n tienda --replicas=2 >/dev/null
$KUBECTL rollout status deployment/api -n tienda --timeout=120s
$KUBECTL get pods -n tienda -l app=api -o wide

POD=$($KUBECTL get pod -n tienda -l app=api -o jsonpath='{.items[0].metadata.name}')
echo
echo "== Borrando $POD =="
$KUBECTL delete pod -n tienda "$POD"

echo
echo "== El Deployment repone la réplica =="
for _ in $(seq 1 30); do
  READY=$($KUBECTL get pods -n tienda -l app=api --no-headers | grep -c ' 1/1 ' || true)
  if [ "$READY" -ge 2 ]; then
    break
  fi
  sleep 2
done
$KUBECTL get pods -n tienda -l app=api -o wide

echo
echo "El pod borrado no vuelve: aparece otro con nombre nuevo."
echo "El ReplicaSet del Deployment compara 2 deseadas con las que hay y crea la que falta."
