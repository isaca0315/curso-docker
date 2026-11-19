#!/usr/bin/env bash
# Deja el clúster de la clase 3 con el stack, Ingress y métricas listos.
# Se puede ejecutar varias veces: no duplica nada y no borra datos.
set -euo pipefail
cd "$(dirname "$0")/lab"

for cmd in docker kind kubectl curl; do
  command -v "$cmd" >/dev/null || { echo "Falta $cmd en PATH" >&2; exit 1; }
done
command -v helm >/dev/null || { echo "Helm no está en PATH (está en ~/.local/bin/helm)" >&2; exit 1; }

if command -v free >/dev/null; then
  avail=$(free -m | awk '/^Mem:/ {print $7}')
  if [ "${avail:-0}" -lt 1500 ]; then
    echo "Aviso: quedan ${avail} MB libres. Cierra aplicaciones antes de la clase." >&2
  fi
fi

if ! kind get clusters | grep -qx curso; then
  # Los puertos solo importan si hay que crear el clúster: si ya existe, los ocupa él.
  if command -v ss >/dev/null; then
    for port in 18020 18443; do
      if ss -ltn | grep -q ":$port "; then
        echo "El puerto $port está ocupado. Libéralo antes de crear el clúster." >&2
        exit 1
      fi
    done
  fi
  kind create cluster --config kind-config.yaml --wait 180s
fi
kubectl config use-context kind-curso >/dev/null

# Tope duro al nodo: si un laboratorio se desboca, el kernel mata pods dentro
# del clúster en vez de congelar el equipo que comparte la videollamada.
# 3.5 GB y el resto para el escritorio; el uso normal ronda 1.5 GB.
docker update --memory 3500m --memory-swap 3500m curso-control-plane >/dev/null \
  || echo "Aviso: no se pudo limitar la memoria del nodo." >&2

kind load docker-image tienda-api:3.0 --name curso

kubectl apply -f manifests/00-namespace.yaml -f manifests/01-secret.yaml
kubectl apply -f manifests/02-postgres.yaml -f manifests/03-redis.yaml
kubectl wait --for=condition=available deployment/db deployment/redis -n tienda --timeout=300s
kubectl apply -f manifests/04-api.yaml
kubectl rollout status deployment/api -n tienda --timeout=300s

if ! kubectl -n ingress-nginx get deployment ingress-nginx-controller >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/kind/deploy.yaml
fi
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=300s

if ! kubectl -n kube-system get deployment metrics-server >/dev/null 2>&1; then
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
fi
if ! kubectl -n kube-system get deployment metrics-server \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q kubelet-insecure-tls; then
  kubectl patch deployment metrics-server -n kube-system --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s

kubectl apply -f manifests/05-ingress.yaml
sleep 5

echo
echo "Nodo:"
kubectl get nodes
echo "Stack:"
kubectl -n tienda get pods,ingress
echo "Prueba por Ingress:"
curl -s -H 'Host: tienda.local' http://localhost:18020/readyz
echo
if command -v free >/dev/null; then
  free -h | head -2
fi
