#!/usr/bin/env bash
# Recorre tres tipos de workload que no son Deployment: Job, CronJob y DaemonSet.
# Crea objetos temporales en el namespace tienda y los borra al final.
set -euo pipefail

cd "$(dirname "$0")/../lab"

KUBECTL=${KUBECTL:-kubectl}
NS=tienda

if ! $KUBECTL get service db -n "$NS" >/dev/null 2>&1; then
  echo "No existe service/db en el namespace $NS." >&2
  echo "Sigue la guía paso a paso antes de ejecutar esta demo." >&2
  exit 1
fi

echo "== Job: corre hasta terminar y queda Completed =="
$KUBECTL apply -f - <<'YAML'
apiVersion: batch/v1
kind: Job
metadata:
  name: reporte
  namespace: tienda
spec:
  backoffLimit: 1
  template:
    metadata:
      labels:
        app: reporte
    spec:
      restartPolicy: Never
      containers:
        - name: psql
          image: postgres:16-alpine
          env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: password
          command: ["sh", "-c"]
          args:
            - psql -h db -U tienda -d tienda -tAc "select count(*) || ' productos, valor ' || coalesce(sum(precio), 0) from productos;"
YAML
$KUBECTL wait --for=condition=complete job/reporte -n "$NS" --timeout=120s
$KUBECTL logs job/reporte -n "$NS"
$KUBECTL get job reporte -n "$NS"

echo
echo "== CronJob: plantilla de Job con horario; este está suspendido =="
$KUBECTL apply -f - <<'YAML'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: reporte-cada-minuto
  namespace: tienda
spec:
  schedule: "*/1 * * * *"
  suspend: true
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: psql
              image: postgres:16-alpine
              env:
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: db-credentials
                      key: password
              command: ["sh", "-c"]
              args:
                - psql -h db -U tienda -d tienda -tAc "select now(), (select count(*) from productos);"
YAML
$KUBECTL get cronjob reporte-cada-minuto -n "$NS"

echo "El horario está suspendido; se lanza un Job a mano desde la misma plantilla:"
$KUBECTL create job reporte-manual --from=cronjob/reporte-cada-minuto -n "$NS"
$KUBECTL wait --for=condition=complete job/reporte-manual -n "$NS" --timeout=120s
$KUBECTL logs job/reporte-manual -n "$NS"

echo
echo "== DaemonSet: un pod en cada nodo, no un número fijo de réplicas =="
$KUBECTL apply -f - <<'YAML'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nodo-info
  namespace: tienda
spec:
  selector:
    matchLabels:
      app: nodo-info
  template:
    metadata:
      labels:
        app: nodo-info
    spec:
      containers:
        - name: info
          image: busybox:1.36
          command: ["sh", "-c", "echo nodo $NODE_NAME; sleep 3600"]
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
YAML
$KUBECTL rollout status daemonset/nodo-info -n "$NS" --timeout=60s
$KUBECTL get pods -n "$NS" -l app=nodo-info -o wide
$KUBECTL logs -l app=nodo-info -n "$NS" --tail=5

echo
echo "== Limpieza =="
$KUBECTL delete daemonset nodo-info -n "$NS" --ignore-not-found
$KUBECTL delete job reporte reporte-manual -n "$NS" --ignore-not-found
$KUBECTL delete cronjob reporte-cada-minuto -n "$NS" --ignore-not-found

echo
echo "Job termina, CronJob repite según el horario y DaemonSet sigue a los nodos."
