#!/usr/bin/env bash
# Un initContainer espera a que Postgres acepte conexiones y solo entonces
# arranca el contenedor principal. El pod no está listo mientras el init corre.
# Requiere el clúster de la clase 3 y el namespace tienda desplegados.
set -euo pipefail

cd "$(dirname "$0")/../lab"

KUBECTL=${KUBECTL:-kubectl}
NS=tienda

if ! $KUBECTL get service db -n "$NS" >/dev/null 2>&1; then
  echo "No existe service/db en el namespace $NS." >&2
  echo "Sigue la guía paso a paso antes de ejecutar esta demo." >&2
  exit 1
fi

$KUBECTL apply -f - <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: init-demo
  namespace: tienda
spec:
  replicas: 1
  selector:
    matchLabels:
      app: init-demo
  template:
    metadata:
      labels:
        app: init-demo
    spec:
      initContainers:
        - name: esperar-db
          image: busybox:1.36
          command:
            - sh
            - -c
            - sleep 3; until nc -z db 5432; do echo esperando db; sleep 2; done; echo db lista
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "echo app arrancada; sleep 3600"]
YAML

echo "== El pod existe, pero el init todavía manda =="
for _ in 1 2 3; do
  $KUBECTL get pods -n "$NS" -l app=init-demo
  sleep 2
done

echo
echo "== Cuando el init termina, arranca el contenedor principal =="
$KUBECTL rollout status deployment/init-demo -n "$NS" --timeout=120s
$KUBECTL get pods -n "$NS" -l app=init-demo -o wide

echo
echo "== Logs del init y de la app =="
$KUBECTL logs deployment/init-demo -n "$NS" -c esperar-db
$KUBECTL logs deployment/init-demo -n "$NS"

echo
echo "== Estado final del pod =="
$KUBECTL get pod -n "$NS" -l app=init-demo \
  -o jsonpath='{.items[0].status.initContainerStatuses[0].state}{"\n"}'

$KUBECTL delete deployment init-demo -n "$NS" --ignore-not-found

echo
echo "El initContainer se ejecuta hasta terminar y no recibe tráfico. El principal no arranca antes."
