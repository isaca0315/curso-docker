# Clase 3 extendida: plan de 8 horas

Versión de día completo de la clase 3. Mantiene el núcleo de 4 horas y suma tres laboratorios: configuración y cuotas (`lab-3c`), Helm (`lab-3d`) y StatefulSet con almacenamiento (`lab-3e`).

**Participantes:** 6 · **Requisitos:** los mismos de la clase de 4 h, más Helm 3.16 · **Clúster:** `kind` de un nodo

## Qué cambia frente a la clase de 4 horas

| Bloque | Clase de 4 h | Clase de 8 h |
|---|---|---|
| Configuración, Job/CronJob y cuotas | no entra | `lab-3c.md` (60 min) |
| Helm | no entra | `lab-3d.md` (60 min) |
| StatefulSet y almacenamiento | no entra | `lab-3e.md` (60 min) |
| Hora extra de reserva | `extra-60-min.md` | sigue disponible, no se usa en el plan |

Los retos de diagnóstico y el entregable son los mismos. El material de la clase de 4 horas no se modifica: la agenda larga lo usa tal cual y agrega los tres laboratorios.

## Agenda (480 min)

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:15 | Repaso de la clase 2 y verificación de `kind` y `kubectl` | `kubectl get nodes` |
| 00:15-01:00 | De Compose a Kubernetes: pods, Deployments, Services, probes, recursos, configuración y workloads | `slides.md` |
| 01:00-02:00 | Lab 3a: crear el clúster, cargar la imagen, desplegar, probar y escalar | `lab/guia-paso-a-paso.md` pasos 0-5 |
| 02:00-02:10 | Pausa | |
| 02:10-02:45 | Operación y demos: auto-reparación, rolling update, rollback, probes, tipos de Service, initContainer y workloads | `demos/01` a `demos/06` |
| 02:45-03:30 | Lab 3b: Ingress, actualización con pausa y rollback, probe rota y HPA | `lab/guia-paso-a-paso.md` pasos 6-9 |
| 03:30-03:40 | Pausa | |
| 03:40-04:40 | Lab 3c: ConfigMap, Job/CronJob y cuotas | `lab/lab-3c.md` |
| 04:40-05:10 | Comida | |
| 05:10-06:10 | Lab 3d: empaquetar la API con Helm | `lab/lab-3d.md` |
| 06:10-06:20 | Pausa | |
| 06:20-07:20 | Lab 3e: StatefulSet y almacenamiento | `lab/lab-3e.md` |
| 07:20-07:55 | Retos de diagnóstico en parejas | `lab/retos-diagnostico.md` |
| 07:55-08:00 | Entregable y cierre | `evaluacion/rubrica-clase-03.md` |

La suma da 480 min: 420 de contenido y 60 de pausas y comida. Si el grupo necesita más aire, recorta el Job en paralelo del `lab-3c`, el `helm package` del `lab-3d` o el paso 9 (HPA) del `lab-3b`; no recortes los retos.

## Antes de la clase

Además de la preparación de la clase de 4 horas:

```bash
# Helm local (una vez)
curl -fsSL -o /tmp/helm.tar.gz https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
tar -xzf /tmp/helm.tar.gz -C /tmp
mkdir -p ~/.local/bin
mv /tmp/linux-amd64/helm ~/.local/bin/helm
helm version --short
```

Comprobar los tres laboratorios nuevos en el clúster de referencia:

```bash
cd clase-03/lab
helm lint helm/tienda
helm template api-helm helm/tienda -n tienda >/dev/null
kubectl apply --dry-run=client -f statefulset/00-namespace.yaml -f statefulset/01-postgres.yaml
```

`lab-3d` no necesita Ingress. `lab-3e` crea su propio namespace; no toca `tienda`.

Para dejar el entorno listo de una vez: `cd clase-03 && ./preparar-clase.sh`. Es idempotente y se puede repetir si el equipo se reinicia.

Si el equipo que proyecta también corre el clúster, ajusta Docker Desktop y cierra lo que no uses antes de la sesión. Los detalles están en [`../modo-bajo-consumo.md`](../modo-bajo-consumo.md).

## Checkpoints por bloques

| Hora | Checkpoint |
|---|---|
| 01:00 | `kubectl get nodes` muestra el nodo `Ready` |
| 02:00 | Cuatro pods `1/1`, PVC `Bound` y `/readyz` responde |
| 02:45 | Explican la auto-reparación, el rollback y qué probe saca del tráfico |
| 03:30 | El Ingress responde con `Host: tienda.local` y el rollback vuelve a 3.0 |
| 04:40 | La versión sale de un ConfigMap, los Jobs terminan y la cuota rechaza pods |
| 06:10 | El upgrade con imagen rota se revierte solo y el rollback vuelve a la 1 |
| 07:20 | `db-0` y `db-1` conservan sus datos y no hay replicación |
| 07:55 | Cada pareja explica un reto con síntoma, causa y comando |

## Si el grupo va atrasado

El mínimo para cerrar el día son el núcleo de 4 horas, el `lab-3c` y uno de los dos laboratorios nuevos. Si hay que elegir, conserva Helm: el `lab-3e` se puede dejar como lectura o tarea.

| Emergencia | Recorte |
|---|---|
| 30 min | Deja el paso 9 (HPA) y los retos 3, 4 y 6 como deberes |
| 60 min | Deja el `lab-3e` como tarea y explica StatefulSet con las diapositivas |
| 90 min | Haz solo la parte 1 del `lab-3c` y salta Helm si el grupo no va a usarlo |

## Entregable de la versión de 8 horas

Además del entregable normal:

- Chart `helm/tienda` validado con `helm lint` y `helm template`.
- `helm history` con al menos dos revisiones y el rollback.
- Salida de `kubectl -n stateful get pods,pvc` antes y después de borrar `db-0`.
- Una frase que explique por qué escalar un StatefulSet no replica los datos.

La rúbrica de la clase sigue siendo la base; el instructor puede sumar estos cuatro puntos como evidencia del día completo.

## Limpieza

```bash
helm uninstall api-helm -n tienda 2>/dev/null || true
kubectl delete namespace stateful --ignore-not-found
kubectl -n tienda get pods
```

No borres el clúster si la clase 4 es al día siguiente. Si no, `kind delete cluster --name curso`.

## Material de reserva

`extra-60-min.md` sigue disponible para un grupo que termine antes: HPA con métricas, depuración de pods y rolling update contra Recreate. No es necesario para completar las 8 horas.
