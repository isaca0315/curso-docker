# Lab 3: índice

Práctica de la clase 3: desplegar `tienda-api` en un clúster local de Kubernetes con `kind`, operarlo y actualizarlo sin caída.

## Empieza aquí

**[Guía paso a paso](guia-paso-a-paso.md)**

Empieza en el paso 0, crea el clúster y sigue el orden. Cada paso incluye el resultado esperado y qué hacer si no coincide.

## Material de apoyo

| Archivo | Contenido |
|---|---|
| [`guia-paso-a-paso.md`](guia-paso-a-paso.md) | Guía completa (pasos 0-9) |
| [`lab-3c.md`](lab-3c.md) | Laboratorio de 60 min: ConfigMap, Job/CronJob y cuotas |
| [`lab-3d.md`](lab-3d.md) | Laboratorio de 60 min: empaquetar la API con Helm |
| [`lab-3e.md`](lab-3e.md) | Laboratorio de 60 min: StatefulSet y almacenamiento |
| [`extra/`](extra/) | Manifiestos del lab 3c |
| [`helm/tienda/`](helm/tienda/) | Chart de la API para el lab 3d |
| [`statefulset/`](statefulset/) | Manifiestos de Postgres como StatefulSet para el lab 3e |
| [`retos-diagnostico.md`](retos-diagnostico.md) | Seis averías cronometradas sobre el clúster |
| [`kind-config.yaml`](kind-config.yaml) | Clúster de un nodo con puertos 18020 y 18443 para el Ingress |
| [`manifests/`](manifests/) | Namespace, Secret, Postgres, Redis, API, Ingress, HPA y generador de carga con límites |
| [`../demos/01-autoreparacion.sh`](../demos/01-autoreparacion.sh) | Borrar un pod y ver el reemplazo |
| [`../demos/02-rolling-update.sh`](../demos/02-rolling-update.sh) | Actualizar la versión y volver atrás |
| [`../demos/03-probe-rota.sh`](../demos/03-probe-rota.sh) | Romper readiness y observar el tráfico |
| [`../demos/04-tipos-service.sh`](../demos/04-tipos-service.sh) | ClusterIP, headless y NodePort |
| [`../demos/05-initcontainer.sh`](../demos/05-initcontainer.sh) | Un initContainer espera a Postgres |
| [`../demos/06-tipos-workload.sh`](../demos/06-tipos-workload.sh) | Job, CronJob y DaemonSet |
| [`../evaluacion/rubrica-clase-03.md`](../evaluacion/rubrica-clase-03.md) | Cómo se evalúa el entregable |

La aplicación es la misma de la clase 2 y vive en [`../../clase-02/lab/app`](../../clase-02/lab/app). No hay una copia para mantener dos versiones del código.

Para el día completo, después de la guía y los retos: [`lab-3c.md`](lab-3c.md), [`lab-3d.md`](lab-3d.md) y [`lab-3e.md`](lab-3e.md). La agenda está en [`../plan-8h.md`](../plan-8h.md).

## Antes de empezar

```bash
kind create cluster --config kind-config.yaml --wait 120s
docker build -t tienda-api:3.0 ../../clase-02/lab/app
kind load docker-image tienda-api:3.0 --name curso
kubectl apply -f manifests/00-namespace.yaml -f manifests/01-secret.yaml
kubectl apply -f manifests/02-postgres.yaml -f manifests/03-redis.yaml
kubectl wait --for=condition=available deployment/db deployment/redis -n tienda --timeout=120s
kubectl apply -f manifests/04-api.yaml
```

El Ingress y el HPA se aplican en los pasos 6 y 9, después de instalar sus controladores.

## Puertos

| Uso | Puerto en el host |
|---|---|
| Ingress (HTTP) | 18020 |
| Ingress (HTTPS) | 18443 |
| Port-forward de pruebas | 18013 |

## Limpieza

```bash
kind delete cluster --name curso
```
