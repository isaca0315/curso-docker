# Guía paso a paso: Lab 3, de Compose a Kubernetes

| Dato | Valor |
|---|---|
| Duración | 105 min de laboratorio: 60 min lab 3a (pasos 0-5) y 45 min lab 3b (pasos 6-9, con HPA si hay `metrics-server`) |
| Directorio de trabajo | `clase-03/lab` |
| Clúster | `kind`, un nodo de control, Kubernetes 1.31 |
| Imagen | `tienda-api:3.0`, construida desde `clase-02/lab/app` |
| Disco libre recomendado | 6 GB |
| Entregable | Manifiestos aplicados + `kubectl rollout history` y el rollback |

## Qué vas a aprender

Al terminar serás capaz de:

1. Crear un clúster local con `kind` y cargar una imagen sin registry.
2. Desplegar API, Postgres y Redis con Deployments, Services y un Ingress.
3. Comprobar auto-reparación, escalado y actualizaciones sin caída.
4. Distinguir liveness de readiness y ver el efecto en el tráfico.
5. Leer el estado real con `kubectl get`, `describe`, `logs` y `events`.

## Mapa de pasos

| Paso | Qué haces | Tiempo |
|---|---|---|
| 0 | Verificar `kind` y `kubectl` | 5 min |
| 1 | Crear el clúster y comprobar el nodo | 9 min |
| 2 | Construir la imagen y cargarla en `kind` | 8 min |
| 3 | Aplicar manifiestos, leer los objetos y ver el estado | 17 min |
| 4 | Probar la API, el Service y el DNS | 12 min |
| 5 | Escalado y estado deseado | 9 min |
| 6 | Ingress | 12 min |
| 7 | Rolling update, pausa y rollback | 15 min |
| 8 | Romper una probe a propósito | 8 min |
| 9 | HPA con carga, limpieza y entregable | 10 min |

## Convenciones

- Todos los comandos se ejecutan desde `clase-03/lab`.
- El clúster se llama `curso` y el namespace `tienda`.
- El Ingress escucha en el puerto 18020 del host; el port-forward de pruebas usa 18013.
- `kind` usa el daemon de Docker. Si usas Docker Desktop, el clúster corre dentro de la VM.
- Los comandos están en bash. En Windows, usa WSL2 o Git Bash: `kind` y `kubectl` funcionan igual.


## Paso 0. Verificar `kind` y `kubectl`

**Objetivo:** tener las dos herramientas en el PATH y comprobar que hablan con Docker. Llegan instaladas de casa; aquí solo se comprueba la versión.

```bash
kind version
kubectl version --client=true
docker info --format '{{.ServerVersion}}'
```

**Esperado:** `kind v0.24.0` o superior, `kubectl v1.31.0` o superior y la versión del daemon.

Si falta alguna, instálala ahora y avisa: Linux x86-64:

```bash
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
curl -Lo kubectl https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl
chmod +x kind kubectl
sudo mv kind kubectl /usr/local/bin/
```

macOS:

```bash
brew install kind kubectl
```

Windows: instala dentro de WSL2 con los comandos de Linux, o usa `choco install kind kubernetes-cli`.

Docker Desktop incluye un Kubernetes propio en Settings > Kubernetes. Sirve para practicar, pero el laboratorio usa `kind` porque permite cargar imágenes locales sin registry y recrear el clúster en segundos. No actives los dos a la vez: compiten por recursos.

**Checkpoint:**

- [ ] `kind version` responde.
- [ ] `kubectl version --client` responde.
- [ ] Docker está arrancado.


## Paso 1. Crear el clúster y comprobar el nodo

**Objetivo:** levantar un clúster de un nodo con los puertos 18020 y 18443 publicados para el Ingress.

```bash
kind create cluster --config kind-config.yaml --wait 120s
kubectl get nodes -o wide
kubectl cluster-info
kubectl config current-context
```

**Esperado:** un nodo `curso-control-plane` en `Ready`, el contexto `kind-curso` y la API en `https://127.0.0.1:...`.

El archivo `kind-config.yaml` marca el nodo con `ingress-ready=true` y publica el 80 y el 443 del nodo en los puertos 18020 y 18443 del host. Sin ese mapeo, el Ingress no sería alcanzable desde el equipo.

Comprueba los espacios de nombres del sistema:

```bash
kubectl get namespaces
kubectl get pods -n kube-system
```

Mira de cuánto espacio dispone el nodo. Es lo que el scheduler reparte entre los pods:

```bash
kubectl describe node curso-control-plane | grep -A6 'Allocatable:'
```

**Esperado:** `cpu: 4`, `memory: 8009932Ki` (unos 8 GB) y `pods: 110`. Con Docker Desktop los números cambian según la memoria y las CPU que le hayas dado a la VM.

**Checkpoint:**

- [ ] El nodo está `Ready`.
- [ ] El contexto es `kind-curso`.
- [ ] Los pods de `kube-system` están `Running`.
- [ ] Sabes cuánta CPU y memoria puede repartir el nodo.


## Paso 2. Construir la imagen y cargarla en `kind`

**Objetivo:** que el clúster use la imagen local sin pasar por un registry.

La app es la misma de la clase 2. Se construye desde ahí para no duplicar código:

```bash
docker build -t tienda-api:3.0 ../../clase-02/lab/app
kind load docker-image tienda-api:3.0 --name curso
```

**Esperado:** `docker build` termina con la imagen de ~220 MB y `kind load` dice que la imagen se cargó en el nodo.

Comprueba que el nodo la ve:

```bash
docker exec curso-control-plane crictl images | grep tienda-api
```

Si el despliegue muestra `ErrImagePull` o `ImagePullBackOff`, la imagen no se cargó o el nombre no coincide exactamente.

**Checkpoint:**

- [ ] La imagen existe en Docker local.
- [ ] `kind load` terminó sin error.
- [ ] `crictl images` la muestra dentro del nodo.


## Paso 3. Aplicar manifiestos y ver el estado

**Objetivo:** desplegar el mismo stack de la clase 2, ahora con objetos de Kubernetes.

```bash
kubectl apply -f manifests/00-namespace.yaml
kubectl apply -f manifests/01-secret.yaml
kubectl apply -f manifests/02-postgres.yaml
kubectl apply -f manifests/03-redis.yaml
kubectl wait --for=condition=available deployment/db deployment/redis -n tienda --timeout=120s
kubectl apply -f manifests/04-api.yaml
kubectl rollout status deployment/api -n tienda --timeout=120s
```

**Esperado:** el namespace `tienda`, el secreto, el PVC, dos Deployments y un rollout de la API con dos réplicas.

Mira lo que se creó:

```bash
kubectl get all -n tienda
kubectl get pvc -n tienda
kubectl get endpoints -n tienda
```

**Esperado:**

```text
pod/api-xxxxxxxxx-aaaaa   1/1   Running
pod/api-xxxxxxxxx-bbbbb   1/1   Running
pod/db-xxxxxxxxx-ccccc    1/1   Running
pod/redis-xxxxxxxxx-ddddd 1/1   Running
pvc/postgres-data         Bound
```

`kubectl get all` no muestra el Ingress ni el PVC; para eso están `kubectl get ingress` y `kubectl get pvc`.

Vuelve a aplicar el mismo manifiesto. Si nada cambió, Kubernetes lo dice:

```bash
kubectl apply -f manifests/04-api.yaml
```

**Esperado:** `deployment.apps/api unchanged` y `service/api unchanged`. `apply` compara lo declarado con lo que ya existe; repetirlo no duplica nada.

Quién crea los pods y cómo se encuentran Service y Deployment:

```bash
kubectl -n tienda get rs
kubectl -n tienda get pods --show-labels
kubectl explain deployment.spec.strategy --recursive | head -12
kubectl -n tienda get events --sort-by=.lastTimestamp | tail -8
```

**Esperado:** un ReplicaSet `api-...` con `DESIRED 2`; cada pod lleva `app=api` y `pod-template-hash`; `explain` describe `RollingUpdate` y `maxSurge`. En los eventos aparece la secuencia `SuccessfulCreate` y `ScalingReplicaSet`.

Los objetos están encadenados: el Deployment crea el ReplicaSet, el ReplicaSet crea los pods y el Service los encuentra por la etiqueta. `kubectl explain` lee la documentación de la versión que corre el clúster, sin buscar en Internet.

El `Secret` con `stringData` es válido para el laboratorio. En un repositorio real no se versiona: se usa Sealed Secrets, External Secrets o el gestor del cloud.

**Checkpoint:**

- [ ] Los cuatro pods están `Running` y `1/1`.
- [ ] El PVC está `Bound`.
- [ ] La API tiene dos réplicas disponibles.


## Paso 4. Probar la API, el Service y el DNS

**Objetivo:** comprobar el balanceo, el DNS interno y que el Service no depende de la IP de un pod.

```bash
kubectl port-forward -n tienda svc/api 18013:8000
```

En otra terminal:

```bash
curl -s localhost:18013/
curl -s localhost:18013/productos
curl -s localhost:18013/visitas
curl -s localhost:18013/readyz
```

**Esperado:**

```json
{"db":"ok","redis":"ok","servicio":"tienda-api","version":"3.0"}
{"productos":[{"id":1,"nombre":"Teclado","precio":25.0}, ...]}
{"status":"ready"}
```

Mira a quién apunta el Service:

```bash
kubectl -n tienda get svc api -o wide
kubectl -n tienda get endpoints api
kubectl -n tienda get pods -l app=api -o wide
```

**Esperado:** el Service tiene una IP `10.96.x.x` y el selector `app=api`; los endpoints son las IP `10.244.x.x` de los dos pods, no la del Service.

El Service no guarda IPs de pods. Borra uno y observa:

```bash
kubectl -n tienda get svc api -o jsonpath='{.spec.clusterIP}{"\n"}'
pod=$(kubectl -n tienda get pods -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl -n tienda delete pod "$pod"
kubectl -n tienda get pods -l app=api -w
```

**Esperado:** aparece un pod nuevo con otra IP, pasa de `0/1` a `1/1` y el Deployment vuelve a tener dos. `Ctrl+C` para salir de `-w`.

```bash
kubectl -n tienda get endpoints api
kubectl -n tienda get svc api -o jsonpath='{.spec.clusterIP}{"\n"}'
```

**Esperado:** los endpoints listan la IP nueva y ya no la vieja; el ClusterIP es el mismo. Por eso el Service sobrevive a los pods. Si el `port-forward` se cerró al borrar el pod, ábrelo otra vez.

Ahora el DNS y la base, desde dentro del clúster:

```bash
kubectl -n tienda exec deploy/api -- python -c "import socket; print(socket.gethostbyname('db')); print(socket.gethostbyname('redis'))"
kubectl -n tienda exec deploy/db -- psql -U tienda -d tienda -c 'select nombre, precio from productos order by id;'
```

**Esperado:** dos IPs `10.96.x.x` y los tres productos. El nombre `db` lo resuelve el DNS del clúster; en ningún manifiesto hay una IP escrita.

**Checkpoint:**

- [ ] Los endpoints responden a través del port-forward.
- [ ] Viste cambiar las IPs de los pods y quedar igual el ClusterIP.
- [ ] `db` y `redis` resuelven por nombre y consultaste la tabla desde `psql`.
- [ ] `/readyz` responde `ready`.


## Paso 5. Escalado y estado deseado

**Objetivo:** ver que el número de réplicas es un campo del Deployment, no un proceso que se arranca a mano.

```bash
kubectl -n tienda scale deployment/api --replicas=3
kubectl -n tienda get pods -l app=api
kubectl -n tienda get endpoints api
kubectl -n tienda get rs
```

**Esperado:** tres pods y tres endpoints. El ReplicaSet de la API marca `DESIRED 3`.

Vuelve a dos, pero haz que el comando falle si el número no es el que esperas:

```bash
kubectl -n tienda scale deployment/api --current-replicas=3 --replicas=2
kubectl -n tienda get pods -l app=api
kubectl -n tienda describe deployment api | tail -8
```

**Esperado:** dos pods y el evento `Scaled down replica set ... to 2`. Si `--current-replicas` no coincide, el comando devuelve error y no cambia nada: sirve para no pisar un escalado que hizo otra persona.

El Deployment no reinicia nada: compara el estado deseado con el real y actúa. Esa es la diferencia con arrancar contenedores a mano.

**Checkpoint:**

- [ ] El escalado cambió pods y endpoints.
- [ ] Entendiste `--current-replicas`.
- [ ] Sabes qué compara el controlador.


## Paso 6. Ingress

**Objetivo:** exponer el Service por nombre de host, sin port-forward.

Instala el controlador de Ingress para `kind`:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
```

Aplica el Ingress y prueba:

```bash
kubectl apply -f manifests/05-ingress.yaml
curl -s -H 'Host: tienda.local' http://localhost:18020/
curl -s -H 'Host: tienda.local' http://localhost:18020/productos
```

**Esperado:** las mismas respuestas que por el port-forward.

Mira cómo quedó registrado el Ingress:

```bash
kubectl get ingressclass
kubectl -n tienda describe ingress api
kubectl -n ingress-nginx logs -l app.kubernetes.io/component=controller --tail=2
```

**Esperado:** la clase `nginx` con controlador `k8s.io/ingress-nginx`; el Ingress con `Host: tienda.local`, ruta `/`, backend `api:http` y las IPs de los pods. En los logs del controlador aparece la petición con `200`.

Prueba a pedir la misma URL sin el `Host`. El controlador no encuentra una regla y responde 404:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18020/
```

**Esperado:** `404`. El Ingress funciona; lo que falta es la regla para ese host.

También puedes añadir la entrada a `/etc/hosts` (en Windows, `C:\Windows\System32\drivers\etc\hosts`):

```text
127.0.0.1 tienda.local
```

Después, <http://tienda.local:18020> funciona en el navegador.

Si recibes 404, el controlador está vivo pero el `host` de la petición no coincide. Si recibes 503, el Service no tiene endpoints listos.

**Checkpoint:**

- [ ] El controlador está `Running`.
- [ ] `curl` con `Host: tienda.local` responde.
- [ ] Sabes distinguir 404 de 503.


## Paso 7. Rolling update, pausa y rollback

**Objetivo:** actualizar sin cortar el servicio, detener un rollout a mitad y volver a una revisión concreta.

Etiqueta la misma imagen con otra versión y simula un despliegue:

```bash
docker tag tienda-api:3.0 tienda-api:3.1
kind load docker-image tienda-api:3.1 --name curso
kubectl set image deployment/api api=tienda-api:3.1 -n tienda
kubectl rollout status deployment/api -n tienda
curl -s localhost:18013/
```

**Esperado:** `version: "3.0"`. La etiqueta de la imagen cambió, pero `APP_VERSION` sigue en 3.0 porque viene del entorno, no de la imagen. Si cerraste el port-forward, ábrelo otra vez: `kubectl port-forward -n tienda svc/api 18013:8000`.

Detén el rollout antes de cambiar la variable:

```bash
kubectl -n tienda rollout pause deployment/api
kubectl -n tienda set env deployment/api APP_VERSION=3.1
sleep 5
kubectl -n tienda get pods -l app=api
kubectl -n tienda rollout history deployment/api
```

**Esperado:** los pods no se mueven y el historial no gana una revisión. Con el Deployment en pausa, el cambio queda guardado pero el controlador no lo aplica.

```bash
kubectl -n tienda rollout resume deployment/api
kubectl -n tienda rollout status deployment/api -n tienda
curl -s localhost:18013/
```

**Esperado:** ahora sí hay pods nuevos y `version: "3.1"`. Con `maxUnavailable: 0` y `maxSurge: 1`, Kubernetes crea uno nuevo antes de retirar uno viejo.

Cada revisión guarda la plantilla completa, no solo la imagen:

```bash
kubectl -n tienda rollout history deployment/api
kubectl -n tienda rollout history deployment/api --revision=1
```

**Esperado:** la revisión 1 muestra `Image: tienda-api:3.0` y `APP_VERSION: 3.0`. Ahí está todo lo que se cambió desde el primer despliegue.

Vuelve atrás una revisión. Ojo: "una atrás" no es "la última que funcionaba":

```bash
kubectl -n tienda rollout undo deployment/api
kubectl -n tienda rollout status deployment/api -n tienda
curl -s localhost:18013/
kubectl -n tienda get pods -l app=api -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
```

**Esperado:** `version: "3.0"` porque la variable volvió a 3.0, pero las dos líneas de imagen dicen `tienda-api:3.1`. El `undo` retrocedió al despliegue de la imagen, que fue el cambio anterior.

Vuelve a la revisión 1 para dejar la imagen original:

```bash
kubectl -n tienda rollout undo deployment/api --to-revision=1
kubectl -n tienda rollout status deployment/api -n tienda
curl -s localhost:18013/
kubectl -n tienda get pods -l app=api -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
```

**Esperado:** `version: "3.0"` y las dos líneas `tienda-api:3.0`. Para volver a una revisión concreta hace falta `--to-revision`; sin número, `undo` solo da un paso atrás.

**Checkpoint:**

- [ ] Viste pods nuevos durante el rollout.
- [ ] El `pause` dejó el cambio sin aplicar y el `resume` lo aplicó.
- [ ] Explicas por qué `undo` dejó la imagen 3.1 con la versión 3.0.
- [ ] Con `--to-revision=1` volviste a la imagen 3.0.


## Paso 8. Romper una probe a propósito

**Objetivo:** comprobar que readiness saca del tráfico sin matar el proceso.

```bash
kubectl patch deployment api -n tienda --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/noexiste"}]'
kubectl rollout status deployment/api -n tienda --timeout=30s || echo "rollout detenido, es lo esperado"
kubectl get pods -n tienda -l app=api
kubectl get endpoints api -n tienda
```

**Esperado:** los pods nuevos quedan `0/1 Running`, el rollout no avanza y el Service sigue apuntando a los pods viejos, que están sanos. La probe de readiness no reinicia nada: solo decide quién recibe tráfico.

Confírmalo con los eventos y el contador de reinicios del pod nuevo:

```bash
kubectl -n tienda get events --field-selector reason=Unhealthy --sort-by=.lastTimestamp | tail -4
pod=$(kubectl -n tienda get pods -l app=api --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[*].metadata.name}' | awk '{print $NF}')
kubectl -n tienda get pod "$pod" -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}'
```

**Esperado:** eventos `Readiness probe failed` con `404` y `0` reinicios. Esa combinación es la prueba de que readiness saca del tráfico sin matar el contenedor.

La liveness sí reinicia. Si cambias `/healthz` por una ruta que no existe, los pods entran en `CrashLoopBackOff` tras fallar tres veces. No lo hagas en el mismo paso: primero entiende readiness.

Restaura la ruta:

```bash
kubectl patch deployment api -n tienda --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/readyz"}]'
kubectl rollout status deployment/api -n tienda --timeout=120s
```

**Checkpoint:**

- [ ] Viste pods `0/1` sin reinicio.
- [ ] Los endpoints no incluían a los pods no listos.
- [ ] Entiendes la diferencia entre liveness y readiness.


## Paso 9. HPA con carga, limpieza y entregable

**Objetivo:** escalar por CPU y cerrar el laboratorio.

Instala `metrics-server` y desactiva la validación TLS del kubelet, que en `kind` usa un certificado propio. Los dos comandos se saltan si ya está hecho, así puedes repetirlos sin miedo:

```bash
kubectl -n kube-system get deployment metrics-server >/dev/null 2>&1 || \
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system get deployment metrics-server \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q kubelet-insecure-tls || \
  kubectl patch deployment metrics-server -n kube-system --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deployment/metrics-server --timeout=120s
kubectl top pods -n tienda
```

Aplica el HPA y genera carga:

```bash
kubectl apply -f manifests/06-hpa.yaml
kubectl apply -f manifests/07-load.yaml
kubectl get hpa -n tienda -w
```

**Esperado (medido):** el HPA pasa de 2 a 3 réplicas con un objetivo de 60 % y un uso real por encima del 150 %. `Ctrl+C` para salir. El pod `load` pide 50m y 32Mi y no puede pasar de 200m y 64Mi: genera tráfico sin quedarse con los recursos de la videollamada.

Limpia la carga y deja que baje:

```bash
kubectl delete pod load -n tienda
kubectl get hpa -n tienda -w
```

El descenso tiene una ventana de estabilización de 60 segundos. Si no baja, revisa `kubectl top pods`.

Entregable:

1. Salida de `kubectl get all -n tienda` con los cuatro pods y dos réplicas de la API.
2. Salida de `kubectl rollout history`, del `undo` y del `undo --to-revision=1`.
3. Captura del HPA antes y después de la carga.
4. Una frase que explique la diferencia entre liveness y readiness.

Limpieza de la carga y el HPA:

```bash
kubectl -n tienda delete pod load --ignore-not-found
kubectl -n tienda delete hpa api --ignore-not-found
kubectl -n tienda scale deployment/api --replicas=2
kubectl -n tienda get pods
```

Borrar el HPA no baja las réplicas: fija el Deployment en el último número que puso. El `scale` lo deja en dos.

**Esperado:** el stack sigue arriba, sin pod `load` ni HPA. No borres el clúster si mañana hay clase 4: lo reutiliza. Si esta es la última sesión:

```bash
kind delete cluster --name curso
docker rmi tienda-api:3.0 tienda-api:3.1 2>/dev/null || true
```

Rúbrica: [`../evaluacion/rubrica-clase-03.md`](../evaluacion/rubrica-clase-03.md).

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `ImagePullBackOff` | La imagen no está en el nodo | `kind load docker-image tienda-api:3.0 --name curso` |
| `kind create` falla por memoria | Docker Desktop con poca RAM | Sube la memoria de la VM a 4 GB o cierra otros contenedores |
| PVC en `Pending` | El clúster no tiene StorageClass por defecto | `kubectl get storageclass`; en `kind` debe existir `standard` |
| `db` no resuelve | El Service no tiene endpoints | `kubectl get endpoints db`; revisa el selector y las labels |
| La API reinicia en bucle | Startup o liveness demasiado estrictas | Revisa `startupProbe`, `kubectl logs` y `describe pod` |
| Rollout atascado | La probe nueva no pasa | `kubectl get pods`, `kubectl describe pod`, `kubectl rollout undo` |
| Ingress devuelve 404 | Falta `Host: tienda.local` | Añade la cabecera o `/etc/hosts` |
| Ingress devuelve 503 | Service sin endpoints listos | `kubectl get endpoints api`; espera la readiness |
| `kubectl top` da `<unknown>` | metrics-server sin `--kubelet-insecure-tls` | Aplica el patch del paso 9 |
| `port-forward` no conecta | El pod no está listo | `kubectl get pods -n tienda` |

## Apéndice A. Chuleta de comandos

```bash
# Clúster
kind create cluster --config kind-config.yaml --wait 120s
kind get clusters
kind delete cluster --name curso
kubectl config current-context

# Imagen
docker build -t tienda-api:3.0 ../../clase-02/lab/app
kind load docker-image tienda-api:3.0 --name curso

# Estado
kubectl get all -n tienda
kubectl get pods -n tienda -o wide
kubectl get rs -n tienda
kubectl get endpoints -n tienda
kubectl get pvc -n tienda
kubectl describe pod -n tienda <pod>
kubectl describe node curso-control-plane | grep -A6 Allocatable
kubectl explain deployment.spec.strategy
kubectl logs -n tienda deploy/api --tail=50
kubectl get events -n tienda --sort-by=.lastTimestamp

# Despliegue
kubectl apply -f manifests/
kubectl apply -f manifests/04-api.yaml
kubectl rollout status deployment/api -n tienda
kubectl rollout history deployment/api -n tienda
kubectl rollout history deployment/api -n tienda --revision=1
kubectl rollout undo deployment/api -n tienda
kubectl rollout undo deployment/api -n tienda --to-revision=1
kubectl rollout pause deployment/api -n tienda
kubectl rollout resume deployment/api -n tienda
kubectl scale deployment/api -n tienda --replicas=3
kubectl scale deployment/api -n tienda --current-replicas=3 --replicas=2
kubectl set env deployment/api APP_VERSION=3.1 -n tienda

# Red
kubectl port-forward -n tienda svc/api 18013:8000
kubectl get ingress -n tienda
kubectl get ingressclass
kubectl describe ingress -n tienda api
kubectl exec deploy/api -n tienda -- getent hosts db

# HPA
kubectl top pods -n tienda
kubectl get hpa -n tienda
kubectl describe hpa api -n tienda
```

## Apéndice B. Resultados medidos

| Comprobación | Resultado |
|---|---|
| Nodo | `curso-control-plane` en `Ready` |
| Capacidad del nodo | 4 CPU, ~8 GB, 110 pods |
| API | 2 réplicas `1/1` |
| Postgres | PVC `Bound`, pod `1/1` |
| Redis | pod `1/1` |
| Port-forward | `18013 -> 8000` |
| Service | ClusterIP igual tras borrar y reponer un pod |
| DNS interno | `db` y `redis` resuelven a IP `10.96.x.x` |
| Ingress | `tienda.local` por `18020`; sin `Host`, 404 |
| Escalado manual | 4 pods y 4 endpoints |
| Rolling update | `3.0 -> 3.1`; `undo` deja imagen 3.1 con versión 3.0 |
| Rollback a la revisión 1 | imagen y `APP_VERSION` en 3.0 |
| Readiness rota | pods nuevos `0/1`, cero reinicios, endpoints con los viejos |
| HPA | 2 -> 3 réplicas con `cpu: 154%/60%` |
| `metrics-server` | necesario el patch `--kubelet-insecure-tls` |

Los tiempos dependen de la máquina y de si la imagen de `kind` ya está descargada.

## Apéndice C. Por qué estos objetos

- **Deployment** mantiene el número de réplicas y hace rolling updates. Un `Pod` suelto no se repara solo.
- **Service** da un nombre y una IP estable. Los pods cambian de IP; el Service no.
- **Ingress** enruta por host y ruta. Necesita un controlador que lo implemente; el objeto solo es la regla.
- **readinessProbe** decide si el pod entra en los endpoints. **livenessProbe** decide si se reinicia. **startupProbe** retrasa las otras dos mientras el proceso arranca.
- **requests** reserva CPU y memoria para el scheduler; **limits** corta el consumo. El HPA calcula el porcentaje sobre los requests.
- **maxUnavailable: 0** evita quedarse sin réplicas durante la actualización, a costa de crear antes de borrar.
