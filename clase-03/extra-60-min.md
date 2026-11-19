# Clase 3: hora extra

Material de reserva para cuando el grupo termina antes de las 4 horas. Tres bloques de 20 minutos, independientes. Con 20 minutos, haz el bloque 1; con 40, el 1 y el 2.

El clúster `curso` tiene que existir y el namespace `tienda` estar desplegado. Los comandos se ejecutan desde `clase-03/lab`.

## Bloque 1. HPA con métricas (20 min)

**Qué se explica:** cómo Kubernetes escala con una métrica real y por qué el descenso no es inmediato.

Comprueba que hay métricas:

```bash
kubectl top pods -n tienda
```

Si devuelve `<unknown>`, falta `metrics-server` o el patch de `--kubelet-insecure-tls` del paso 9. Sin métricas, salta este bloque.

Aplica el HPA, genera carga y observa:

```bash
kubectl apply -f manifests/06-hpa.yaml
kubectl apply -f manifests/07-load.yaml
kubectl get hpa -n tienda -w
```

**Esperado:** el HPA pasa de 2 a 3 réplicas con objetivo del 60 % y uso actual por encima del 150 %.

Detalle de la decisión:

```bash
kubectl describe hpa api -n tienda
```

Señala la ventana de estabilización de 60 segundos. Borra la carga y deja que baje:

```bash
kubectl delete pod load -n tienda
kubectl get hpa -n tienda -w
```

**Esperado:** las réplicas bajan después de la ventana, no de inmediato. `Ctrl+C` para salir.

Si no hay `metrics-server`, haz el mismo efecto a mano:

```bash
kubectl scale deployment api -n tienda --replicas=3
kubectl get pods -n tienda -w
kubectl scale deployment api -n tienda --replicas=2
```

**Checkpoint:** el alumno explica qué mira el HPA, cada cuánto y por qué no baja al instante.

## Bloque 2. Depurar un pod (20 min)

**Qué se explica:** leer el estado y los eventos antes de reiniciar a ciegas.

Primero un fallo de imagen:

```bash
kubectl set image deployment/api api=tienda-api:no-existe -n tienda
kubectl get pods -n tienda -w
```

**Esperado:** `ImagePullBackOff` o `ErrImagePull`. En otra terminal:

```bash
kubectl describe deployment api -n tienda | tail -15
kubectl get events -n tienda --sort-by=.lastTimestamp | tail -10
kubectl rollout undo deployment/api -n tienda
```

Ahora un contenedor que arranca y muere:

```bash
kubectl patch deployment api -n tienda --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/command","value":["sh","-c","echo fallo deliberado; exit 1"]}]'
kubectl get pods -n tienda -w
```

**Esperado:** `CrashLoopBackOff` con reinicios crecientes. Mira el log del intento anterior:

```bash
POD=$(kubectl get pod -n tienda -l app=api --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
kubectl logs -n tienda "$POD" --tail=20
kubectl describe pod -n tienda "$POD" | tail -20
```

Restaura quitando el `command`:

```bash
kubectl patch deployment api -n tienda --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/command"}]'
kubectl rollout status deployment/api -n tienda
```

Por último, entra en un pod existente y comprueba DNS y conectividad desde dentro:

```bash
kubectl exec -it -n tienda deploy/api -- sh
```

Dentro: `getent hosts db` y `python -c "import urllib.request; print(urllib.request.urlopen('http://api:8000/healthz').read().decode())"`. `exit` para salir.

**Checkpoint:** el alumno distingue un fallo de imagen de uno de arranque y sabe dónde mirar cada uno.

## Bloque 3. Rolling update contra Recreate (20 min)

**Qué se explica:** qué se pierde cuando la actualización para todos los pods a la vez.

Prepara la versión nueva y una sonda de disponibilidad:

```bash
docker tag tienda-api:3.0 tienda-api:3.1
kind load docker-image tienda-api:3.1 --name curso
while true; do date +%T; curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Host: tienda.local' http://localhost:18020/healthz; sleep 0.5; done
```

Si no hay Ingress, usa `kubectl port-forward -n tienda svc/api 18013:8000` y apunta el bucle a `http://localhost:18013/healthz`.

Con el bucle en marcha, cambia la estrategia y actualiza:

```bash
kubectl -n tienda patch deployment api --type=merge \
  -p '{"spec":{"strategy":{"type":"Recreate"}}}'
kubectl -n tienda set image deployment/api api=tienda-api:3.1
kubectl -n tienda rollout status deployment/api
```

**Esperado:** durante el hueco, el bucle imprime `503` o cortes de conexión. Todos los pods viejos mueren antes de crear los nuevos.

Vuelve a rolling y repite:

```bash
kubectl -n tienda set image deployment/api api=tienda-api:3.0
kubectl -n tienda patch deployment api --type=merge \
  -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":0,"maxSurge":1}}}}'
kubectl -n tienda set image deployment/api api=tienda-api:3.1
kubectl -n tienda rollout status deployment/api
```

**Esperado:** el bucle mantiene `200`. Con `maxUnavailable: 0` Kubernetes crea uno nuevo antes de retirar uno viejo.

Deja la versión del laboratorio:

```bash
kubectl -n tienda set image deployment/api api=tienda-api:3.0
kubectl -n tienda rollout status deployment/api
```

**Checkpoint:** el alumno relaciona `maxUnavailable` y `maxSurge` con lo que ve en el bucle.

## Si solo hay 20 minutos

Bloque 1, si hay `metrics-server`. Si no, bloque 2, que no depende de métricas.

## Si hay 40 minutos

Bloques 1 y 2. El 3 necesita el Ingress o el port-forward y deja el clúster en la versión del laboratorio.
