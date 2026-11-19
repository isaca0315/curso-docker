# Retos de diagnóstico: clase 3

Seis averías sobre el clúster de `kind` y los manifiestos de `clase-03/lab`. Se resuelven en parejas y se deshacen al final.

| Dato | Valor |
|---|---|
| Duración | 35 min |
| Directorio | `clase-03/lab` |
| Requisito | Clúster `curso` con el namespace `tienda` aplicado y la API en 2 réplicas |
| Formato | Parejas: una persona ejecuta, la otra lee `describe` y decide |

## Reglas

- Antes de tocar nada: `kubectl -n tienda get pods,svc,endpoints`.
- Para cada reto escribe tres líneas: síntoma, causa y comando que lo confirma.
- Usa `kubectl describe` y `kubectl logs` antes de reiniciar o borrar.
- Al terminar, restaura con los manifiestos de `manifests/` y comprueba que el rollout termina.

## Reto 1. El pod se queda en Pending (6 min)

**Síntoma:** un despliegue nuevo no arranca y el rollout no termina.

```bash
kubectl -n tienda patch deployment api --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"64"},{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"64"}]'

kubectl -n tienda get pods -l app=api
POD=$(kubectl -n tienda get pods -l app=api --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')
kubectl -n tienda describe pod "$POD" | sed -n '/Events:/,$p'
```

**Esperado:** aparece un pod nuevo en `Pending`; los dos anteriores siguen `1/1`. En los eventos:

```text
0/1 nodes are available: 1 Insufficient cpu
```

**Diagnóstico:** el scheduler no puede colocar el pod porque el `request` de CPU supera lo que queda libre en el nodo. No es un problema de imagen ni de red. Con `maxUnavailable: 0` y `maxSurge: 1`, Kubernetes crea el pod nuevo antes de retirar uno viejo, así que el servicio sigue arriba y el rollout se queda esperando.

**Arreglo:**

```bash
kubectl -n tienda rollout undo deployment/api
kubectl -n tienda rollout status deployment/api --timeout=120s
```

**Comprobación:** los pods vuelven a `1/1` y el rollout termina.

## Reto 2. El Service no tiene endpoints (5 min)

**Síntoma:** el Ingress devuelve 503 aunque los pods están `Running`.

```bash
kubectl -n tienda patch service api \
  -p '{"spec":{"selector":{"app":"api-v2"}}}'

sleep 5
kubectl -n tienda get endpoints api
kubectl -n tienda get pods --show-labels
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: tienda.local' localhost:18020/
```

**Esperado:** el endpoint aparece como `<none>`, los pods siguen con la etiqueta `app=api` y el `curl` devuelve `503`.

**Diagnóstico:** el selector del Service no coincide con ninguna etiqueta de pod. El Service existe y tiene puerto, pero su lista de endpoints está vacía, así que el Ingress no tiene a quién enviar el tráfico. Un 503 aquí no es un fallo del Ingress.

**Arreglo:**

```bash
kubectl -n tienda patch service api -p '{"spec":{"selector":{"app":"api"}}}'
sleep 5
kubectl -n tienda get endpoints api
```

**Comprobación:** el endpoint lista las IPs de los dos pods y el `curl` devuelve 200.

## Reto 3. El secreto nuevo bloquea el rollout (8 min)

**Síntoma:** se cambió la contraseña de la base y el despliegue no avanza, pero la versión vieja sigue respondiendo.

```bash
kubectl -n tienda create secret generic db-credentials \
  --from-literal=password=otra-clave \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n tienda rollout restart deployment/api
kubectl -n tienda rollout status deployment/api --timeout=90s || echo "rollout detenido, es lo esperado"
kubectl -n tienda get pods -l app=api
```

**Esperado:** el rollout no termina. Hay un pod nuevo `0/1 Running` con cero reinicios y los dos anteriores siguen `1/1` sirviendo tráfico. En `describe` del pod nuevo aparece la readiness fallando con 503. La API tarda cerca de 60 segundos en empezar a escuchar porque reintenta la conexión antes de arrancar; por eso la espera es de 90 segundos. El `startupProbe` cubre ese arranque lento y evita que la liveness reinicie el pod mientras tanto.

El error exacto se ve dentro del pod nuevo:

```bash
pod=$(kubectl -n tienda get pods -l app=api \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[*].metadata.name}' | awk '{print $NF}')

kubectl -n tienda exec "$pod" -- python -c \
  "import http.client; c=http.client.HTTPConnection('127.0.0.1',8000); c.request('GET','/readyz'); r=c.getresponse(); print(r.status, r.read().decode())"
```

**Esperado:** `password authentication failed for user "tienda"`.

**Diagnóstico:** Postgres ya estaba inicializado con la contraseña anterior. El secreto nuevo solo cambia lo que envía la API; la base sigue con la clave vieja. La readiness usa `/readyz`, que comprueba la conexión, así que el pod nuevo nunca entra en el Service. La liveness usa `/healthz`, que responde aunque la base falle; el `startupProbe` retrasa la liveness hasta que gunicorn escucha, por eso el pod se queda en `0/1` sin reiniciarse.

**Arreglo:** vuelve a aplicar el secreto original y reinicia el despliegue. No hace falta tocar la base.

```bash
kubectl apply -f manifests/01-secret.yaml
kubectl -n tienda rollout restart deployment/api
kubectl -n tienda rollout status deployment/api --timeout=180s
```

**Comprobación:** los pods nuevos pasan a `1/1` y `/readyz` responde `ready`.

## Reto 4. El Ingress apunta a un puerto que no existe (6 min)

**Síntoma:** el Ingress devuelve 503 y el Service tiene endpoints.

```bash
kubectl -n tienda patch ingress api --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/name","value":"web"}]'

sleep 5
kubectl -n tienda describe ingress api | tail -15
kubectl -n tienda get svc api -o jsonpath='{.spec.ports[*].name}{"\n"}'
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: tienda.local' localhost:18020/
```

**Esperado:** el Ingress muestra el puerto `web`, el Service solo declara `http` y el `curl` devuelve `503`. En los logs del controlador aparece que no encuentra el puerto `web`.

**Diagnóstico:** el Ingress referencia el puerto por nombre. El Service declara `name: http`; `web` no existe. Los endpoints están bien, pero el controlador no sabe a qué puerto enviar. Es un fallo de contrato entre dos objetos, no de la aplicación.

**Arreglo:**

```bash
kubectl -n tienda patch ingress api --type=json \
  -p='[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/name","value":"http"}]'
```

**Comprobación:** el `curl` vuelve a 200.

Si el clúster no tiene Ingress, cambia este reto por uno de `targetPort`: apunta el Service a `targetPort: web` y comprueba que el port-forward falla aunque los endpoints existan. El diagnóstico es el mismo: el nombre del puerto no coincide.

## Reto 5. El pod se reinicia sin parar (5 min)

**Síntoma:** el rollout no avanza y el pod nuevo cambia de estado cada pocos segundos.

```bash
kubectl -n tienda patch deployment api --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"16Mi"},{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"16Mi"}]'
sleep 25
kubectl -n tienda get pods -l app=api
pod=$(kubectl -n tienda get pods -l app=api --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[*].metadata.name}' | awk '{print $NF}')
kubectl -n tienda describe pod "$pod" | grep -A3 'Last State'
```

**Esperado:** el pod nuevo está en `CrashLoopBackOff`, con `RESTARTS` mayor que cero, y `Last State` dice `Terminated`, `Reason: OOMKilled`, `Exit Code: 137`. Los dos pods anteriores siguen `1/1`.

**Diagnóstico:** el límite de memoria es más chico de lo que ocupa el proceso. El kernel lo mata y el kubelet lo reinicia con espera creciente. No es un error de la aplicación ni de la imagen: `OOMKilled` y el código 137 lo confirman. Bajar un límite sin medir el consumo es una forma habitual de romper un despliegue.

**Arreglo:**

```bash
kubectl -n tienda rollout undo deployment/api
kubectl -n tienda rollout status deployment/api --timeout=180s
```

**Comprobación:** los pods vuelven a `1/1` y dejan de aparecer reinicios nuevos.

## Reto 6. La imagen no existe (5 min)

**Síntoma:** el pod nuevo no arranca y el rollout no avanza, pero la versión vieja sigue respondiendo.

```bash
kubectl -n tienda set image deployment/api api=tienda-api:9.9
sleep 10
kubectl -n tienda get pods -l app=api
pod=$(kubectl -n tienda get pods -l app=api --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[*].metadata.name}' | awk '{print $NF}')
kubectl -n tienda describe pod "$pod" | sed -n '/Events:/,$p' | tail -5
```

**Esperado:** `ErrImagePull` o `ImagePullBackOff` en el pod nuevo y eventos `Failed to pull image "tienda-api:9.9"`. Los pods anteriores siguen `1/1` y sirviendo.

**Diagnóstico:** el tag no está en el nodo ni en un registry. `ImagePullBackOff` es un problema de imagen; `Pending` es de recursos y `CrashLoopBackOff` es del proceso. Se distinguen leyendo el estado y los eventos, sin reiniciar nada.

**Arreglo:**

```bash
kubectl -n tienda rollout undo deployment/api
kubectl -n tienda rollout status deployment/api --timeout=180s
```

**Comprobación:** los pods vuelven a `1/1` y el rollout termina.

## Restaurar el entorno

```bash
kubectl apply -f manifests/01-secret.yaml
kubectl -n tienda rollout restart deployment/api
kubectl -n tienda rollout status deployment/api --timeout=180s
kubectl -n tienda get pods,svc,endpoints
kubectl -n tienda get deploy api -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
curl -s -H 'Host: tienda.local' localhost:18020/healthz
```

**Esperado:** dos pods `1/1`, el mismo ClusterIP y los recursos originales (`cpu: 250m`, `memory: 256Mi` de límite). Los retos 1, 5 y 6 ya se revirtieron con `rollout undo`.

Si el reto 1 dejó una revisión mala en el historial, `rollout undo` ya la revirtió. No borres el clúster: la clase 4 reutiliza los manifiestos y el overlay.

## Checklist de cierre

- [ ] Distingo `Pending` de `ImagePullBackOff` y de `CrashLoopBackOff`.
- [ ] Sé leer los eventos de `describe pod`.
- [ ] Reconozco `OOMKilled` y el código 137.
- [ ] Sé comprobar endpoints antes de culpar al Ingress.
- [ ] Entiendo por qué un pod puede estar `Running` y `0/1` a la vez.
- [ ] Sé qué probe reinicia y cuál solo saca del tráfico.
- [ ] Dejé el clúster sano y el secreto original aplicado.
