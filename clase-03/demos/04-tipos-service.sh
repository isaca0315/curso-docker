#!/usr/bin/env bash
# Muestra los tres tipos de Service que se usan en el curso:
# ClusterIP (api), headless y NodePort.
# Requiere el clúster de la clase 3 y el namespace tienda desplegados.
set -euo pipefail

cd "$(dirname "$0")/../lab"

KUBECTL=${KUBECTL:-kubectl}
NS=tienda

if ! $KUBECTL get service api -n "$NS" >/dev/null 2>&1; then
  echo "No existe service/api en el namespace $NS." >&2
  echo "Sigue la guía paso a paso antes de ejecutar esta demo." >&2
  exit 1
fi

echo "== ClusterIP: una IP estable delante de los pods =="
$KUBECTL get service api -n "$NS" -o wide
$KUBECTL get endpointslices -n "$NS" -l kubernetes.io/service-name=api

echo
echo "== Headless: sin IP de servicio, el DNS devuelve las IP de los pods =="
$KUBECTL apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: api-headless
  namespace: tienda
spec:
  clusterIP: None
  selector:
    app: api
  ports:
    - name: http
      port: 8000
      targetPort: http
YAML

$KUBECTL -n "$NS" run dns-probe --image=busybox:1.36 --restart=Never --command -- \
  sh -c 'nslookup api; echo ---; nslookup api-headless.tienda.svc.cluster.local; sleep 2'

$KUBECTL -n "$NS" wait --for=jsonpath='{.status.phase}'=Succeeded pod/dns-probe --timeout=60s
$KUBECTL -n "$NS" logs dns-probe
$KUBECTL -n "$NS" delete pod dns-probe --ignore-not-found

echo
echo "== NodePort: el mismo Service, además, en un puerto de cada nodo =="
$KUBECTL apply -f - <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: api-node
  namespace: tienda
spec:
  type: NodePort
  selector:
    app: api
  ports:
    - name: http
      port: 8000
      targetPort: http
      nodePort: 30080
YAML
$KUBECTL get service api-node -n "$NS"

echo
echo "El NodePort 30080 abre en la IP de cada nodo, no en localhost."
echo "En kind no está publicado al host; el Ingress sigue siendo la entrada del laboratorio."

$KUBECTL delete service api-headless api-node -n "$NS" --ignore-not-found
echo
echo "ClusterIP para lo interno, headless para descubrir pods uno por uno y NodePort para exponer sin Ingress."
