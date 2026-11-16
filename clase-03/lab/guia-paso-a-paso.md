# Guía paso a paso: Lab 3, de Compose a Kubernetes

| Dato | Valor |
|---|---|
| Duración | 4 h de clase; 90 min de laboratorio (55 min lab 3a + 35 min lab 3b) más 10 min de HPA si hay `metrics-server` |
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
| 1 | Crear el clúster y comprobar el nodo | 8 min |
| 2 | Construir la imagen y cargarla en `kind` | 8 min |
| 3 | Aplicar manifiestos y ver el estado | 15 min |
| 4 | Probar la API y los Services | 8 min |
| 5 | Auto-reparación y escalado | 10 min |
| 6 | Ingress | 10 min |
| 7 | Rolling update y rollback | 10 min |
| 8 | Romper una probe a propósito | 8 min |
| 9 | HPA con carga | 10 min |

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

**Checkpoint:**

- [ ] El nodo está `Ready`.
- [ ] El contexto es `kind-curso`.
- [ ] Los pods de `kube-system` están `Running`.


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

El `Secret` con `stringData` es válido para el laboratorio. En un repositorio real no se versiona: se usa Sealed Secrets, External Secrets o el gestor del cloud.

**Checkpoint:**

- [ ] Los cuatro pods están `Running` y `1/1`.
- [ ] El PVC está `Bound`.
- [ ] La API tiene dos réplicas disponibles.


## Paso 4. Probar la API y los Services

**Objetivo:** comprobar que el Service hace balanceo y que el DNS interno resuelve.

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

El Service `api` reparte entre las dos réplicas. Comprueba el DNS desde un pod:

```bash
kubectl exec deploy/api -n tienda -- python -c "import socket; print(socket.gethostbyname('db')); print(socket.gethostbyname('redis'))"
```

**Esperado:** dos IPs del rango de Services (`10.96.x.x` por defecto), no las IPs de los pods. Kubernetes resuelve el nombre del Service a una IP virtual.

**Checkpoint:**

- [ ] Los endpoints responden a través del port-forward.
- [ ] `db` y `redis` resuelven por nombre.
- [ ] `/readyz` responde `ready`.


## Paso 5. Auto-reparación y escalado

**Objetivo:** ver el bucle de reconciliación y el escalado declarativo.

Borra un pod de la API:

```bash
kubectl delete pod -n tienda $(kubectl get pod -n tienda -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl get pods -n tienda -l app=api -w
```

**Esperado:** el pod borrado desaparece y el Deployment crea otro hasta volver a dos réplicas. `Ctrl+C` para salir de `-w`.

Escala a cuatro réplicas:

```bash
kubectl scale deployment/api -n tienda --replicas=4
kubectl get pods -n tienda -l app=api
kubectl get endpoints api -n tienda
```

**Esperado:** cuatro pods y cuatro IPs en el Service. Vuelve a dos:

```bash
kubectl scale deployment/api -n tienda --replicas=2
```

El Deployment no "reinicia" nada: compara el estado deseado con el real y actúa. Esa es la diferencia con arrancar contenedores a mano.

**Checkpoint:**

- [ ] Viste un pod nuevo tras borrar uno.
- [ ] El escalado cambió pods y endpoints.
- [ ] Entiendes qué compara el controlador.


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


## Paso 7. Rolling update y rollback

**Objetivo:** actualizar sin cortar el servicio y volver atrás.

Etiqueta la misma imagen con otra versión y simula un despliegue:

```bash
docker tag tienda-api:3.0 tienda-api:3.1
kind load docker-image tienda-api:3.1 --name curso
kubectl set image deployment/api api=tienda-api:3.1 -n tienda
kubectl rollout status deployment/api -n tienda
```

La etiqueta cambió, pero `APP_VERSION` sigue en `3.0` porque viene del entorno. Cambia la variable para ver la versión nueva:

```bash
kubectl set env deployment/api APP_VERSION=3.1 -n tienda
kubectl rollout status deployment/api -n tienda
kubectl get pods -n tienda -l app=api
curl -s localhost:18013/
```

Si cerraste el port-forward del paso 4, ábrelo otra vez en otra terminal: `kubectl port-forward -n tienda svc/api 18013:8000`.

**Esperado:** `version: "3.1"` y pods nuevos. Con `maxUnavailable: 0` y `maxSurge: 1`, Kubernetes crea uno nuevo antes de retirar uno viejo.

Guarda la evidencia y vuelve atrás:

```bash
kubectl rollout history deployment/api -n tienda
kubectl rollout undo deployment/api -n tienda
kubectl rollout status deployment/api -n tienda
curl -s localhost:18013/
```

**Esperado:** la versión vuelve a `3.0`. `rollout history` muestra las revisiones; `undo` sin número vuelve a la anterior.

**Checkpoint:**

- [ ] Viste pods nuevos durante el rollout.
- [ ] La versión cambió a 3.1 y volvió a 3.0.
- [ ] Tienes la salida de `rollout history` y del `undo`.


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

Instala `metrics-server` y desactiva la validación TLS del kubelet, que en `kind` usa un certificado propio:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl rollout status deployment/metrics-server -n kube-system --timeout=120s
kubectl top pods -n tienda
```

Aplica el HPA y genera carga:

```bash
kubectl apply -f manifests/06-hpa.yaml
kubectl run load --image=busybox:1.36 --restart=Never -n tienda -- \
  sh -c 'while true; do wget -q -O /dev/null http://api:8000/productos; done'
kubectl get hpa -n tienda -w
```

**Esperado (medido):** el HPA pasa de 2 a 5 réplicas con un objetivo de 60 % y un uso real por encima del 150 %. `Ctrl+C` para salir.

Limpia la carga y deja que baje:

```bash
kubectl delete pod load -n tienda
kubectl get hpa -n tienda -w
```

El descenso tiene una ventana de estabilización de 60 segundos. Si no baja, revisa `kubectl top pods`.

Entregable:

1. Salida de `kubectl get all -n tienda` con los cuatro pods y dos réplicas de la API.
2. Salida de `kubectl rollout history` y del `undo`.
3. Captura del HPA antes y después de la carga.
4. Una frase que explique la diferencia entre liveness y readiness.

Limpieza:

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
| La API reinicia en bucle | Liveness falla antes de que arranque | Sube `initialDelaySeconds` o revisa `kubectl logs` |
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
kubectl get endpoints -n tienda
kubectl get pvc -n tienda
kubectl describe pod -n tienda <pod>
kubectl logs -n tienda deploy/api --tail=50
kubectl get events -n tienda --sort-by=.lastTimestamp

# Despliegue
kubectl apply -f manifests/
kubectl rollout status deployment/api -n tienda
kubectl rollout history deployment/api -n tienda
kubectl rollout undo deployment/api -n tienda
kubectl scale deployment/api -n tienda --replicas=4
kubectl set env deployment/api APP_VERSION=3.1 -n tienda

# Red
kubectl port-forward -n tienda svc/api 18013:8000
kubectl get ingress -n tienda
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
| API | 2 réplicas `1/1` |
| Postgres | PVC `Bound`, pod `1/1` |
| Redis | pod `1/1` |
| Port-forward | `18013 -> 8000` |
| Ingress | `tienda.local` por `18020` |
| Auto-reparación | pod nuevo en menos de 10 s |
| Escalado manual | 4 pods y 4 endpoints |
| Rolling update | `3.0 -> 3.1 -> 3.0` |
| Readiness rota | pods nuevos `0/1`, endpoints con los viejos |
| HPA | 2 -> 5 réplicas con `cpu: 154%/60%` |
| `metrics-server` | necesario el patch `--kubelet-insecure-tls` |

Los tiempos dependen de la máquina y de si la imagen de `kind` ya está descargada.

## Apéndice C. Por qué estos objetos

- **Deployment** mantiene el número de réplicas y hace rolling updates. Un `Pod` suelto no se repara solo.
- **Service** da un nombre y una IP estable. Los pods cambian de IP; el Service no.
- **Ingress** enruta por host y ruta. Necesita un controlador que lo implemente; el objeto solo es la regla.
- **readinessProbe** decide si el pod entra en los endpoints. **livenessProbe** decide si se reinicia.
- **requests** reserva CPU y memoria para el scheduler; **limits** corta el consumo. El HPA calcula el porcentaje sobre los requests.
- **maxUnavailable: 0** evita quedarse sin réplicas durante la actualización, a costa de crear antes de borrar.
