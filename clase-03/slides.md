---
marp: true
theme: default
paginate: true
header: "Docker Avanzado · Clase 3"
style: |
  section { font-size: 22px; }
---

# Docker Avanzado

## Clase 3: orquestación y Kubernetes con `kind`

4 horas · 6 participantes · El stack de la clase 2 en un clúster local

---

# Contenido

1. Qué problema resuelve un orquestador
2. Pods, Deployments y Services
3. Probes, recursos y autoescalado
4. Ingress y actualizaciones sin caída
5. Lab: desplegar, romper y recuperar `tienda-api`

**Hilo del curso:** el stack de Compose se convierte hoy en objetos de Kubernetes; en la clase 4 se asegura y se automatiza.

---

# Lo que Compose no hace

| Necesidad | Compose en un host | Kubernetes |
|---|---|---|
| Varias réplicas | `--scale` manual | Declarado y reconciliado |
| Reponer un contenedor caído | `restart: unless-stopped` | ReplicaSet crea otro pod |
| Actualizar sin caída | depende de ti | Rolling update con probes |
| Repartir tráfico | un proxy a mano | Service + Ingress |
| Escalar por carga | no | HPA con métricas |

Compose describe contenedores en un host. Kubernetes describe el estado deseado de un sistema.

---

# Arquitectura de un clúster

```text
kubectl
   |
   v
control plane
  apiserver  etcd  scheduler  controller-manager
       |
       v
  kubelet + container runtime
       |
   [ pods ]
```

El apiserver es el único punto de entrada. Todo lo demás observa y reconcilia.

---

# Piezas de `kind`

```bash
kind create cluster --config kind-config.yaml
```

- `kind` ejecuta un nodo de Kubernetes dentro de un contenedor Docker.
- El nodo es un contenedor, no una VM.
- Los puertos del nodo se publican con `extraPortMappings`.
- Las imágenes locales se cargan con `kind load docker-image`.

Sirve para aprender y para CI. No es un clúster de producción.

---

# Pod: la unidad mínima

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api
spec:
  containers:
    - name: api
      image: tienda-api:3.0
      ports:
        - containerPort: 8000
```

Un pod tiene su propia IP y comparte red entre sus contenedores.

Un pod suelto no se repara: si el nodo lo pierde, no vuelve.

---

# Deployment: estado deseado

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: tienda-api:3.0
```

El Deployment crea un ReplicaSet, y el ReplicaSet crea los pods.

---

# Bucle de reconciliación

```text
estado deseado (etcd)
        |
        v
controlador compara
        |
        +--> faltan réplicas -> crea pods
        +--> sobran réplicas  -> borra pods
        +--> imagen nueva     -> rolling update
```

Declaras el resultado y el controlador trabaja hasta conseguirlo. No hay una secuencia de pasos que ejecutar.

---

# Service: nombre estable

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
    - port: 8000
      targetPort: http
```

- El selector elige pods por label.
- Los endpoints son las IPs de los pods listos.
- `api` resuelve a `10.96.x.x`, no a la IP del pod.
- Sin endpoints, el Service no entrega tráfico.

---

# Descubrimiento por DNS

```text
pod de la API
  /etc/resolv.conf -> 10.96.0.10
        |
        v
  CoreDNS
        |
        +--> api      -> 10.96.12.34   (Service)
        +--> db       -> 10.96.45.67   (Service)
        +--> redis    -> 10.96.78.90   (Service)
```

Es el mismo patrón que el DNS embebido de Docker, con otro plano de control.

---

# Probes: dos preguntas distintas

| Probe | Pregunta | Si falla |
|---|---|---|
| `livenessProbe` | ¿El proceso sigue vivo? | Reinicia el contenedor |
| `readinessProbe` | ¿Puede recibir tráfico? | Lo saca de los endpoints |
| `startupProbe` | ¿Ya arrancó? | Retrasa las otras dos |

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: http
  periodSeconds: 5
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 15
```

---

# Liveness mal puesta

```text
/healthz consulta Postgres
        |
   Postgres lento
        |
liveness falla 3 veces
        |
reinicia la API
        |
más carga sobre Postgres
```

Una liveness que depende de un servicio externo puede convertir un fallo ajeno en un bucle de reinicios.

`/healthz` comprueba el proceso. `/readyz` comprueba las dependencias.

---

# Requests y limits

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 250m
    memory: 256Mi
```

- `requests`: lo que el scheduler reserva. El HPA calcula sobre esto.
- `limits`: el techo. Pasarse de CPU limita; pasarse de memoria mata el pod.
- Sin requests, el HPA no puede calcular porcentajes.

---

# Rolling update

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

```text
2 pods viejos
  -> 3 pods (2 viejos + 1 nuevo)
  -> 2 viejos + 2 nuevos
  -> 1 viejo + 2 nuevos
  -> 2 nuevos
```

Si el pod nuevo no queda listo, el rollout se detiene. Los viejos siguen sirviendo.

---

# Rollback

```bash
kubectl rollout status deployment/api -n tienda
kubectl rollout history deployment/api -n tienda
kubectl rollout undo deployment/api -n tienda
```

`undo` sin número vuelve a la revisión anterior. El historial se guarda en el Deployment (`revisionHistoryLimit`).

---

# Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
spec:
  ingressClassName: nginx
  rules:
    - host: tienda.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  name: http
```

El objeto solo es la regla. Necesita un controlador que la lea y configure un proxy.

---

# Ingress en `kind`

```yaml
extraPortMappings:
  - containerPort: 80
    hostPort: 18020
  - containerPort: 443
    hostPort: 18443
```

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/kind/deploy.yaml
curl -H 'Host: tienda.local' http://localhost:18020/
```

404 significa que el controlador vive pero el host no coincide. 503 significa que el Service no tiene endpoints.

---

# HPA

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    kind: Deployment
    name: api
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          averageUtilization: 60
```

Necesita `metrics-server`. En `kind`, el patch `--kubelet-insecure-tls`.

---

# `docker compose` contra `kubectl`

| Tarea | Compose | Kubernetes |
|---|---|---|
| Arrancar | `docker compose up -d` | `kubectl apply -f` |
| Ver estado | `docker compose ps` | `kubectl get pods` |
| Logs | `docker compose logs` | `kubectl logs` |
| Escalar | `--scale api=3` | `kubectl scale` |
| Actualizar | rebuild + up | `kubectl set image` |
| Volver atrás | rebuild | `kubectl rollout undo` |

El concepto se repite; cambia quién reconcilia el estado.

---

# Lab 3a (55 min)

1. Verificar `kind` y `kubectl`
2. Crear el clúster y comprobar el nodo
3. Construir la imagen y cargarla en `kind`
4. Aplicar manifiestos y ver el estado
5. Probar la API y los Services
6. Auto-reparación y escalado

Guía: `lab/guia-paso-a-paso.md`

---

# Lab 3b (35 min)

1. Instalar `ingress-nginx` y publicar `tienda.local`
2. Rolling update a 3.1 y rollback a 3.0
3. Romper readiness y ver los pods `0/1`
4. Instalar `metrics-server` y el HPA
5. Generar carga y ver el escalado
6. Limpiar el clúster

Entregable: manifiestos aplicados + historial + rollback + captura del HPA.

---

# Errores típicos

| Síntoma | Causa |
|---|---|
| `ImagePullBackOff` | La imagen no está en el nodo |
| PVC en `Pending` | No hay StorageClass por defecto |
| La API reinicia en bucle | Liveness demasiado agresiva |
| Rollout atascado | La readiness nueva no pasa |
| Ingress 404 | Falta el `Host` correcto |
| Ingress 503 | Service sin endpoints |
| `kubectl top` en `<unknown>` | metrics-server sin el patch TLS |

---

# Cierre

Checklist:

- [ ] Creo un clúster con `kind` y cargo una imagen local
- [ ] Describo un Deployment con réplicas, probes y recursos
- [ ] Distingo Service de Ingress
- [ ] Explico auto-reparación y rolling update
- [ ] Sé qué hace readiness y qué hace liveness
- [ ] Leo el estado con `get`, `describe`, `logs` y `events`

**Próxima clase:** seguridad de la imagen y pipeline de CI/CD.

<!--
Notas para el instructor:
- No instalar el Ingress antes del paso 6: el controlador tarda y distrae.
- Tener el YAML de ingress-nginx y metrics-server descargado si falla la conexión.
- La demo de HPA necesita 60-90 segundos antes de mostrar el escalado.
- Si la memoria va justa, saltar el HPA y dejar los manifiestos como lectura.
-->
