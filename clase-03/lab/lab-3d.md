# Lab 3d: empaquetar la API con Helm

**Duración:** 60 min · **Requisitos:** clúster `curso` con el namespace `tienda` desplegado y sano, Helm 3.16 o superior · **Material:** [`helm/tienda/`](helm/tienda/)

El objetivo es convertir los manifiestos de la API en un chart, instalarlo como release aparte y actualizarlo sin editar YAML a mano. Todo se ejecuta desde `clase-03/lab`.

## Parte 1. Ver el chart y renderizarlo (10 min)

```bash
helm version --short
find helm/tienda -type f | sort
cat helm/tienda/values.yaml
```

**Esperado:** `v3.16` o superior y cinco archivos. `replicaCount`, `image.tag`, `appVersion` y `resources` salen de `values.yaml`; las plantillas los insertan con `{{ .Values... }}`.

Valida y renderiza sin tocar el clúster:

```bash
helm lint helm/tienda
helm template api-helm helm/tienda --namespace tienda | head -40
```

**Esperado:** `1 chart(s) linted, 0 chart(s) failed` y un YAML con `kind: Deployment`, `kind: Service` y los valores ya sustituidos. `template` no crea nada: es la misma idea que `docker compose config`.

**Checkpoint:** el alumno distingue `values.yaml` de las plantillas y sabe que `template` solo imprime.

## Parte 2. Instalar el release (15 min)

El chart usa el Postgres, Redis y secreto que ya existen en el namespace. Deja la API original en una réplica y instala:

```bash
kubectl -n tienda scale deployment/api --replicas=1
kubectl -n tienda rollout status deployment/api --timeout=120s
helm install api-helm helm/tienda --namespace tienda
kubectl -n tienda rollout status deployment/api-helm --timeout=300s
helm list -n tienda
kubectl -n tienda get deploy,svc,pods -l app=api-helm
```

**Esperado:** el release en `deployed`, con `deployment/api-helm` y `service/api-helm`, dos pods `1/1`, y la API original en una réplica.

Mira lo que Helm guardó:

```bash
helm get values api-helm -n tienda
helm get manifest api-helm -n tienda | head -20
```

`get manifest` es el YAML exacto que se aplicó. `get values` muestra solo lo que se pasó por `--set` o `-f`, no los valores por defecto.

**Checkpoint:** el alumno explica qué es un release y en qué se diferencia de un chart.

## Parte 3. Actualizar y volver atrás (20 min)

Un upgrade puede tomar los valores de un archivo. [`extra/valores-demo.yaml`](extra/valores-demo.yaml) cambia réplicas, versión y límites de CPU. Míralo primero en seco:

```bash
helm upgrade api-helm helm/tienda --namespace tienda \
  -f extra/valores-demo.yaml --dry-run | grep -E 'replicas:|value:|cpu:'
```

**Esperado:** `replicas: 2`, `value: "3.2"` y `cpu: 300m`. `--dry-run` renderiza sin tocar el clúster.

Aplícalo y comprueba:

```bash
helm upgrade api-helm helm/tienda --namespace tienda -f extra/valores-demo.yaml
kubectl -n tienda rollout status deployment/api-helm --timeout=300s
helm get values api-helm -n tienda
kubectl -n tienda exec deploy/api-helm -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read().decode())"
```

**Esperado:** `"version":"3.2"` y dos pods. La etiqueta cambió pero la imagen sigue siendo `3.0`: `appVersion` es un valor del chart, no el tag de la imagen.

Ahora cambia réplicas y versión con `--set`:

```bash
helm upgrade api-helm helm/tienda --namespace tienda \
  --set replicaCount=3 --set appVersion=3.1
kubectl -n tienda rollout status deployment/api-helm --timeout=300s
helm history api-helm -n tienda
kubectl -n tienda exec deploy/api-helm -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read().decode())"
```

**Esperado:** tres pods, tres revisiones en el historial y `"version":"3.1"`.

Prueba qué pasa con una imagen que no existe. `--atomic` deshace el upgrade solo:

```bash
helm upgrade api-helm helm/tienda --namespace tienda \
  --reuse-values --set image.tag=9.9 --atomic --timeout 30s
```

**Esperado:** el comando espera, falla con `UPGRADE FAILED ... rolled back due to atomic being set: context deadline exceeded` y deja la release como estaba. Tarda alrededor de un minuto. Comprueba que no quedó nada roto:

```bash
helm history api-helm -n tienda
kubectl -n tienda get pods -l app=api-helm
```

**Esperado:** tres pods `1/1`, una revisión con estado `failed` y otra `deployed`. Sin `--atomic`, el upgrade se queda a medias esperando a que la imagen aparezca.

Vuelve a la revisión 1:

```bash
helm rollback api-helm 1 -n tienda
kubectl -n tienda rollout status deployment/api-helm --timeout=300s
helm history api-helm -n tienda
kubectl -n tienda exec deploy/api-helm -- python -c \
  "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/').read().decode())"
```

**Esperado:** dos pods, una revisión nueva en el historial y `"version":"3.0"`. Helm no borra revisiones: agrega una que devuelve el estado anterior.

**Checkpoint:** el alumno relaciona `upgrade` y `rollback` con `kubectl set` y `kubectl rollout undo`, y sabe por qué el historial lo lleva Helm.

## Parte 4. Desinstalar y limpiar (8 min)

```bash
helm uninstall api-helm -n tienda
kubectl -n tienda scale deployment/api --replicas=2
kubectl -n tienda rollout status deployment/api --timeout=300s
kubectl -n tienda get deploy,svc -l app=api-helm
```

**Esperado:** no quedan el Deployment ni el Service `api-helm`. La API original vuelve a dos réplicas y el resto del namespace sigue igual.

**Checkpoint:** el alumno sabe que `uninstall` borra los objetos del release, no los del namespace.

## Parte 5. Empaquetar el chart (7 min)

Un chart también se distribuye como `.tgz`. Empaqueta e instala el archivo:

```bash
helm package helm/tienda
helm install api-pkg tienda-api-0.1.0.tgz --namespace tienda
kubectl -n tienda rollout status deployment/api-pkg --timeout=300s
helm list -n tienda
```

**Esperado:** un archivo `tienda-api-0.1.0.tgz` y un release `api-pkg` con `deployment/api-pkg` y dos pods. El `.tgz` es el chart completo con sus valores por defecto.

Desinstala y borra el paquete:

```bash
helm uninstall api-pkg -n tienda
rm tienda-api-0.1.0.tgz
kubectl -n tienda get deploy,svc -l app=api-pkg
```

**Esperado:** no quedan objetos `api-pkg`. El release `api-helm` ya no existe desde la parte 4; la API original sigue en dos réplicas.

**Checkpoint:** el alumno sabe que `helm install` acepta un directorio o un `.tgz`, y que el paquete no lleva los valores que se pasaron por `--set`.

## Si algo no coincide

| Síntoma | Causa probable | Solución |
|---|---|---|
| `helm lint` falla por YAML | Error de indentación en una plantilla | `helm template` muestra la línea; corrige y repite |
| `ImagePullBackOff` en `api-helm` | La imagen no está en el nodo | `kind load docker-image tienda-api:3.0 --name curso` |
| `upgrade` no cambia la versión | Se cambió `image.tag` y no `appVersion`, o al revés | Mira `helm get values` y `kubectl get deploy api-helm -o yaml` |
| `rollback` no vuelve a dos pods | La revisión indicada no es la esperada | `helm history api-helm -n tienda` y usa el número correcto |
