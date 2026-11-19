# Lab 3e: StatefulSet y almacenamiento

**Duración:** 60 min · **Requisitos:** clúster `curso` en marcha · **Material:** [`statefulset/`](statefulset/)

El objetivo es ver qué agrega un StatefulSet sobre un Deployment: nombre estable, DNS propio y un volumen por réplica. Se trabaja en el namespace `stateful` para no tocar `tienda`.

## Parte 1. Crear el StatefulSet (15 min)

```bash
kubectl apply -f statefulset/00-namespace.yaml -f statefulset/01-postgres.yaml
kubectl -n stateful rollout status statefulset/db --timeout=300s
kubectl -n stateful get pods,pvc,svc -o wide
```

**Esperado:** un pod `db-0` en `1/1`, un PVC `data-db-0` en `Bound` y un Service `db` con `CLUSTER-IP` en `None`. Ese `None` es el Service headless.

El nombre no es aleatorio: el StatefulSet usa ordinales (`db-0`, `db-1`, ...) y crea el PVC con el nombre del template más el ordinal.

Comprueba el DNS estable:

```bash
kubectl -n stateful run dns-probe --image=busybox:1.36 --restart=Never --command -- \
  nslookup db.stateful.svc.cluster.local
kubectl -n stateful wait --for=jsonpath='{.status.phase}'=Succeeded pod/dns-probe --timeout=60s
kubectl -n stateful logs dns-probe
kubectl -n stateful delete pod dns-probe
```

**Esperado:** el DNS devuelve la IP de `db-0`, no la IP virtual de un Service. Eso pasa por ser headless.

Cada réplica tiene además su propio nombre. Resuelve el de `db-0`:

```bash
kubectl -n stateful run dns-pod --image=busybox:1.36 --restart=Never --command -- \
  nslookup db-0.db.stateful.svc.cluster.local
kubectl -n stateful wait --for=jsonpath='{.status.phase}'=Succeeded pod/dns-pod --timeout=60s
kubectl -n stateful logs dns-pod
kubectl -n stateful delete pod dns-pod
```

**Esperado:** la misma IP de `db-0`. Ese nombre (`pod.servicio.namespace`) permite apuntar a una réplica concreta, cosa que un Deployment no ofrece.

**Checkpoint:** el alumno explica para qué sirve `serviceName` y por qué el Service es headless.

## Parte 2. Los datos sobreviven al pod (15 min)

```bash
kubectl -n stateful exec db-0 -- psql -U tienda -d tienda -c \
  "create table visitas (id serial primary key, nota text); insert into visitas (nota) values ('sobrevive al pod');"
kubectl -n stateful exec db-0 -- psql -U tienda -d tienda -tAc \
  "select nota from visitas;"
```

**Esperado:** `CREATE TABLE`, `INSERT 0 1` y `sobrevive al pod`.

Borra el pod y espera a que vuelva:

```bash
kubectl -n stateful delete pod db-0
kubectl -n stateful rollout status statefulset/db --timeout=300s
kubectl -n stateful get pods,pvc
kubectl -n stateful exec db-0 -- psql -U tienda -d tienda -tAc \
  "select nota from visitas;"
```

**Esperado:** vuelve el mismo `db-0`, con el mismo PVC y la fila intacta. En un Deployment el pod tendría otro nombre y, sin volumen persistente, la base arrancaría vacía.

**Checkpoint:** el alumno distingue el volumen del pod del PVC que lo respalda.

## Parte 3. Escalar no es replicar (20 min)

```bash
kubectl -n stateful scale statefulset/db --replicas=2
kubectl -n stateful rollout status statefulset/db --timeout=300s
kubectl -n stateful get pods,pvc
```

**Esperado:** aparecen `db-1` y un PVC nuevo `data-db-1`. Cada réplica tiene su propio volumen.

Consulta las dos bases:

```bash
kubectl -n stateful exec db-0 -- psql -U tienda -d tienda -tAc "select nota from visitas;"
kubectl -n stateful exec db-1 -- psql -U tienda -d tienda -tAc "select count(*) from visitas;"
```

**Esperado:** `db-0` conserva la fila; `db-1` responde `ERROR: relation "visitas" does not exist`. El StatefulSet dio identidad y volumen, no replicación.

Escribe algo en `db-1`, quita la segunda réplica y vuelve a crearla:

```bash
kubectl -n stateful exec db-1 -- psql -U tienda -d tienda -c \
  "create table suyos (id serial primary key, nota text); insert into suyos (nota) values ('solo en db-1');"
kubectl -n stateful scale statefulset/db --replicas=1
kubectl -n stateful rollout status statefulset/db --timeout=300s
kubectl -n stateful get pods,pvc
kubectl -n stateful scale statefulset/db --replicas=2
kubectl -n stateful rollout status statefulset/db --timeout=300s
kubectl -n stateful exec db-1 -- psql -U tienda -d tienda -tAc "select nota from suyos;"
```

**Esperado:** al bajar a una, se retira `db-1` (el ordinal más alto) y su PVC `data-db-1` queda ahí. Al volver a dos, `db-1` recupera ese mismo PVC y la fila `solo en db-1` sigue. La identidad del ordinal es lo que amarra pod y volumen.

**Checkpoint:** el alumno sabe que escalar un StatefulSet sin replicación no reparte datos, y que cada ordinal conserva su volumen.

## Parte 4. Reinicio ordenado y limpieza (10 min)

Reinicia los pods y observa el orden:

```bash
kubectl -n stateful rollout restart statefulset/db
kubectl -n stateful rollout status statefulset/db --timeout=300s
kubectl -n stateful get pods
```

**Esperado:** primero se reinicia `db-1` y, cuando vuelve, `db-0`. El controlador no toca los dos a la vez. Los datos siguen en sus PVC.

Limpia el namespace:

```bash
kubectl delete namespace stateful
kubectl get namespace stateful
```

**Esperado:** el namespace desaparece con sus pods y PVC. Es la forma más rápida de limpiar; no borres PVC sueltos si vas a repetir la práctica.

**Checkpoint:** el alumno explica cuándo usaría StatefulSet y cuándo un Deployment con un PVC compartido no sirve.

## Si algo no coincide

| Síntoma | Causa probable | Solución |
|---|---|---|
| `db-0` en `Pending` | No hay StorageClass por defecto | `kubectl get storageclass`; en `kind` debe existir `standard` |
| El PVC queda `Pending` | La StorageClass no aprovisiona | Revisa `kubectl describe pvc data-db-0 -n stateful` |
| `db-0` no arranca | El volumen tiene datos incompatibles | `kubectl -n stateful logs db-0`; borra el namespace y repite |
| `db-1` tiene los mismos datos | Estás mirando el PVC de `db-0` | Cada réplica tiene su PVC; no hay replicación automática |
