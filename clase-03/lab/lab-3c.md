# Lab 3c: configuración, trabajos y cuotas

**Duración:** 60 min · **Requisitos:** clúster `curso` con el namespace `tienda` desplegado y sano · **Material:** [`extra/`](extra/)

Tres partes independientes de 20 minutos. Si solo hay 20, haz la parte 1. Todo se ejecuta desde `clase-03/lab`.

Si aplicaste el HPA en el paso 9, quítalo para que no cambie las réplicas mientras trabajas:

```bash
kubectl -n tienda delete hpa api --ignore-not-found
```

## Parte 1. ConfigMap: variables y archivos (20 min)

**Objetivo:** separar la configuración de la imagen y ver qué se actualiza solo y qué necesita reiniciar.

[`extra/configmap.yaml`](extra/configmap.yaml) trae dos ConfigMap: uno con una variable y otro con un archivo. Aplica y conecta la variable:

```bash
kubectl apply -f extra/configmap.yaml
kubectl -n tienda set env deployment/api APP_VERSION-
kubectl -n tienda set env deployment/api --from=configmap/api-env
kubectl rollout status deployment/api -n tienda --timeout=180s
kubectl exec deploy/api -n tienda -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read().decode())"
```

**Esperado:** `"version":"3.0-cm"`. Los dos `set env` van separados: juntos, el segundo no agrega el `envFrom`.

Cambia el ConfigMap, lee, reinicia y vuelve a leer:

```bash
kubectl -n tienda create configmap api-env \
  --from-literal=APP_VERSION=3.0-cm2 \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl exec deploy/api -n tienda -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read().decode())"
kubectl -n tienda rollout restart deployment/api
kubectl rollout status deployment/api -n tienda --timeout=180s
kubectl exec deploy/api -n tienda -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read().decode())"
```

**Esperado:** la primera lectura sigue en `"version":"3.0-cm"`, porque la variable se leyó al arrancar el contenedor. Después del rollout dice `"version":"3.0-cm2"`.

Un ConfigMap montado como volumen se comporta distinto. Agrégalo y lee el archivo:

```bash
kubectl -n tienda patch deployment api --type=strategic -p '{
  "spec":{"template":{"spec":{
    "containers":[{"name":"api","volumeMounts":[{"name":"config","mountPath":"/etc/tienda","readOnly":true}]}],
    "volumes":[{"name":"config","configMap":{"name":"api-archivo"}}]
  }}}
}'
kubectl rollout status deployment/api -n tienda --timeout=180s
kubectl exec deploy/api -n tienda -- cat /etc/tienda/saludo.txt
```

**Esperado:** `hola desde un ConfigMap montado`.

Cambia el archivo y espera un minuto. El kubelet sincroniza el volumen sin reiniciar:

```bash
kubectl -n tienda create configmap api-archivo \
  --from-literal=saludo.txt='saludo actualizado sin reiniciar' \
  --dry-run=client -o yaml | kubectl apply -f -
sleep 60
kubectl exec deploy/api -n tienda -- cat /etc/tienda/saludo.txt
```

**Esperado:** `saludo actualizado sin reiniciar`.

Devuelve la API a su estado original:

```bash
kubectl -n tienda replace --force -f manifests/04-api.yaml
kubectl rollout status deployment/api -n tienda --timeout=180s
kubectl -n tienda delete configmap api-env api-archivo --ignore-not-found
```

**Esperado:** la API vuelve a `"version":"3.0"`, sin `envFrom` ni volúmenes extra.

**Checkpoint:** el alumno explica por qué una variable del entorno no cambia sin reiniciar y un archivo montado sí.

## Parte 2. Job y CronJob (20 min)

**Objetivo:** ejecutar tareas que terminan, en lugar de procesos que quedan corriendo.

[`extra/job-reporte.yaml`](extra/job-reporte.yaml) consulta la base y termina:

```bash
kubectl apply -f extra/job-reporte.yaml
kubectl wait --for=condition=complete job/reporte -n tienda --timeout=120s
kubectl logs job/reporte -n tienda
kubectl get job,pod -l job-name=reporte -n tienda
```

**Esperado:** `3 productos, valor 220.00`, el Job `Complete 1/1` y el pod `Completed`, no `Running`.

Ahora uno que falla, con `backoffLimit: 0` para no reintentar:

```bash
kubectl apply -f extra/job-falla.yaml
kubectl wait --for=condition=failed job/falla -n tienda --timeout=60s
kubectl logs job/falla -n tienda
kubectl describe job falla -n tienda | tail -6
```

**Esperado:** `fallo deliberado`, el Job `Failed 0/1`, el pod `Error` y el evento `BackoffLimitExceeded`. Sin `backoffLimit`, el Job reintentaría con esperas crecientes.

El CronJob está suspendido para no llenar el namespace de Jobs, pero su plantilla se puede lanzar a mano:

```bash
kubectl delete job reporte falla -n tienda
kubectl apply -f extra/cronjob-reporte.yaml
kubectl get cronjob reporte-cada-minuto -n tienda
kubectl -n tienda create job reporte-manual --from=cronjob/reporte-cada-minuto
kubectl wait --for=condition=complete job/reporte-manual -n tienda --timeout=120s
kubectl logs job/reporte-manual -n tienda
```

**Esperado:** `SUSPEND=True` y, del Job manual, una línea con la fecha y el número de productos.

Para verlo crear Jobs solo: `kubectl -n tienda patch cronjob reporte-cada-minuto --type=merge -p '{"spec":{"suspend":false}}'` y mira `kubectl get jobs -n tienda -w`. Limpia al terminar:

```bash
kubectl delete cronjob reporte-cada-minuto -n tienda
kubectl delete job reporte-manual -n tienda --ignore-not-found
```

Un Job también puede repartir el trabajo. [`extra/job-paralelo.yaml`](extra/job-paralelo.yaml) pide 4 ejecuciones y permite 2 a la vez:

```bash
kubectl apply -f extra/job-paralelo.yaml
sleep 6
kubectl get pods -l job-name=paralelo -n tienda
kubectl wait --for=condition=complete job/paralelo -n tienda --timeout=180s
kubectl get job paralelo -n tienda
kubectl get pods -l job-name=paralelo -n tienda
kubectl delete job paralelo -n tienda
```

**Esperado:** al principio hay uno o dos pods, no cuatro; los demás arrancan cuando los primeros terminan. Al final, `COMPLETIONS 4/4` y cuatro pods `Completed`. Tarda uno o dos minutos. `ttlSecondsAfterFinished` los borraría solo a los cinco minutos.

**Checkpoint:** el alumno distingue un proceso que queda corriendo de un Job que termina y sabe para qué sirve un CronJob.

## Parte 3. Cuota y límites (20 min)

**Objetivo:** poner un techo al namespace y ver qué pasa cuando el despliegue lo supera.

Deja la API en una réplica para no cargar el equipo:

```bash
kubectl -n tienda scale deployment/api --replicas=1
kubectl rollout status deployment/api -n tienda --timeout=180s
```

[`extra/cuota.yaml`](extra/cuota.yaml) trae el `LimitRange` y la cuota:

```bash
kubectl apply -f extra/cuota.yaml
kubectl -n tienda describe quota tienda-quota
```

**Esperado:** `3` pods de `4`, `200m` de CPU de `500m` y `256Mi` de memoria de `512Mi`.

El `LimitRange` pone recursos por defecto a quien no los declara:

```bash
kubectl -n tienda run sin-recursos --image=busybox:1.36 --restart=Never --command -- sleep 60
kubectl -n tienda get pod sin-recursos -o jsonpath='{.spec.containers[0].resources}{"\n"}'
```

**Esperado:** `{"limits":{"cpu":"200m","memory":"128Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}`, sin haberlos escrito.

El `LimitRange` también impone un máximo por contenedor. Un pod que pide 1 CPU no llega a crearse:

```bash
kubectl delete pod sin-recursos -n tienda
kubectl apply -f extra/pod-limite.yaml
```

**Esperado:** `Forbidden ... maximum cpu usage per Container is 500m, but limit is 1`. No aparece en `kubectl get pods`: lo rechazó la admisión.

La cuota no solo cuenta pods, también suma `requests`. Un pod que pide 400m de CPU no cabe:

```bash
kubectl apply -f extra/pod-cpu.yaml
```

**Esperado:** `exceeded quota: tienda-quota, requested: requests.cpu=400m, used: requests.cpu=200m, limited: requests.cpu=500m`.

Ahora pide tres réplicas de la API. La cuota no deja crear la tercera:

```bash
kubectl -n tienda scale deployment/api --replicas=3
sleep 12
kubectl -n tienda get pods -l app=api
kubectl get events -n tienda --sort-by=.lastTimestamp | grep -i quota | tail -5
```

**Esperado:** dos pods de la API y el evento:

```text
Error creating: pods "api-..." is forbidden: exceeded quota: tienda-quota,
requested: pods=1, used: pods=4, limited: pods=4
```

El pod que falta no está `Pending`: el API Server rechazó su creación. El ReplicaSet lo reintenta en cada vuelta.

Quita la cuota y aparece la réplica que estaba bloqueada:

```bash
kubectl delete resourcequota tienda-quota -n tienda
kubectl rollout status deployment/api -n tienda --timeout=180s
kubectl -n tienda get pods -l app=api
```

**Esperado:** tres pods. La cuota era la puerta, no el scheduler.

Vuelve a dos réplicas y borra el `LimitRange`:

```bash
kubectl -n tienda scale deployment/api --replicas=2
kubectl rollout status deployment/api -n tienda --timeout=180s
kubectl delete limitrange tienda-limits -n tienda
kubectl -n tienda get pods,resourcequota,limitrange
```

**Esperado:** dos pods de la API y el namespace sin cuota ni límites por defecto. Si quieres el HPA de vuelta: `kubectl apply -f manifests/06-hpa.yaml`.

**Checkpoint:** el alumno distingue un pod `Pending` de uno que la cuota rechazó antes de existir, y sabe que `requests` es lo que reserva el scheduler.

## Si algo no coincide

| Síntoma | Causa probable | Solución |
|---|---|---|
| La versión no cambia a `3.0-cm` | El `envFrom` no se agregó | Ejecuta los dos `set env` por separado y revisa `kubectl get deploy api -o yaml` |
| El archivo montado no se actualiza | Aún no pasó el minuto de sincronización | Espera 60 s y vuelve a leer |
| El pod del Job queda `Error` | La base no responde o la contraseña cambió | `kubectl logs job/reporte`; restaura el secreto y reintenta |
| La cuota no deja crear el pod de prueba | Ya está en el tope de pods | Borra el pod de prueba y revisa `describe quota` |
| `replace --force` tarda | Borra y recrea Deployment y Service | Espera `rollout status`; es el comportamiento esperado |
