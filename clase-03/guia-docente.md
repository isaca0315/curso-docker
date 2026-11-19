# Guía del docente: clase 3

Guion de sesión para las 4 horas. Los tiempos son relativos al inicio (00:00). La guía del alumno es [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md) y se sigue en paralelo. El instructor comparte pantalla.

## Modalidad virtual

Cada participante crea su clúster de `kind` en su equipo y sigue la guía en paralelo. El clúster pide cerca de 2 GB de RAM, así que conviene cerrar máquinas virtuales y navegadores con muchas pestañas antes de la sesión. Las imágenes y los YAML de los controladores se descargan antes, no durante el laboratorio.

**Material que conviene tener abierto:** [`slides.md`](slides.md), [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md), [`lab/retos-diagnostico.md`](lab/retos-diagnostico.md), [`lab/lab-3c.md`](lab/lab-3c.md), [`evaluacion/rubrica-clase-03.md`](evaluacion/rubrica-clase-03.md) y una copia impresa de [`recursos/checklist-kubernetes.md`](recursos/checklist-kubernetes.md) por participante.

## Antes de la clase

### El día anterior

Pedir a los participantes que lleguen con `kind` y `kubectl` instalados y con la imagen del nodo descargada. La instalación y la descarga no son el objetivo de la clase y consumen el tiempo del laboratorio.

```bash
kind version
kubectl version --client
docker pull kindest/node:v1.31.0
```

Preparar las imágenes y el clúster de referencia:

```bash
docker pull kindest/node:v1.31.0
docker pull busybox:1.36
docker pull postgres:16-alpine
docker pull redis:7-alpine

cd clase-03/lab
kind create cluster --config kind-config.yaml --wait 120s
docker build -t tienda-api:3.0 ../../clase-02/lab/app
kind load docker-image tienda-api:3.0 --name curso
```

Descargar los YAML de los controladores para no depender de la conexión de cada participante:

```bash
curl -L -o /tmp/ingress-nginx.yaml \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/kind/deploy.yaml
curl -L -o /tmp/metrics-server.yaml \
  https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Para la versión de 8 horas, instalar Helm y probar los laboratorios nuevos:

```bash
curl -fsSL -o /tmp/helm.tar.gz https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
tar -xzf /tmp/helm.tar.gz -C /tmp
mv /tmp/linux-amd64/helm ~/.local/bin/helm
helm version --short

cd clase-03/lab
helm lint helm/tienda
helm template api-helm helm/tienda -n tienda >/dev/null
kubectl apply --dry-run=client -f statefulset/00-namespace.yaml -f statefulset/01-postgres.yaml
```

Si el equipo que proyecta también corre el clúster, ajusta Docker Desktop a 2 CPU y 4 GB, cierra los stacks que no uses y no dupliques el clúster. Los detalles están en [`../modo-bajo-consumo.md`](../modo-bajo-consumo.md).

### Quince minutos antes

- Si el equipo se reinició o quieres partir de cero, ejecuta `./preparar-clase.sh`: crea el clúster, pone el techo de 3.5 GB al nodo, carga la imagen, despliega el stack e instala Ingress y métricas.
- Comprobar que 18020, 18443 y 18013 están libres: `ss -ltn | grep -E '18020|18443|18013'`.
- Verificar que el clúster responde: `kubectl get nodes` y `kubectl -n tienda get pods`.
- Cada participante debe tener 8 GB de RAM en el equipo y 2 GB libres para el clúster. Un clúster con Ingress y métricas ronda los 1.5 GB.
- Ejecutar una vez los seis demos. Los demos 04 y 05 crean y borran sus objetos; el 06 limpia al final. El demo 02 deja la imagen en 3.1 y la variable en 3.0; volver a aplicar `manifests/04-api.yaml` antes de la clase si se quiere el estado limpio.
- Probar los retos en el clúster de referencia. El reto 4 necesita el Ingress; si no está instalado, usar la variante de `targetPort` que indica el documento.
- Recorrer `lab/lab-3c.md` una vez. La parte 3 deja el namespace sin cuota ni `LimitRange`; comprobar al final que la API vuelve a dos réplicas. Los dos pods de rechazo (`pod-limite.yaml` y `pod-cpu.yaml`) no se crean: no hay nada que borrar.
- Probar el upgrade fallido del `lab-3d` fuera de clase: `--atomic` tarda cerca de un minuto y deja una revisión `failed` en el historial. Si el laboratorio se corta antes de `helm uninstall`, esa revisión sigue ahí; se limpia con `helm uninstall api-helm -n tienda`.

## Agenda

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:10 | Repaso de la clase 2 y verificación de `kind` y `kubectl` | `kubectl get nodes` |
| 00:10-00:50 | De Compose a Kubernetes: pods, Deployments, Services, probes, recursos, configuración y workloads | `slides.md` |
| 00:50-01:50 | Lab 3a, pasos 0 a 5 | `lab/guia-paso-a-paso.md` |
| 01:50-02:00 | Pausa | |
| 02:00-02:30 | Operación: auto-reparación, rolling update, rollback y probes | `slides.md` + `demos/01-autoreparacion.sh` + `demos/02-rolling-update.sh` + `demos/03-probe-rota.sh` |
| 02:30-03:15 | Lab 3b, pasos 6 a 9 (incluye el HPA) | `lab/guia-paso-a-paso.md` |
| 03:15-03:50 | Retos de diagnóstico en parejas | `lab/retos-diagnostico.md` |
| 03:50-04:00 | Entregable y cierre | `evaluacion/rubrica-clase-03.md` |

No borrar el clúster al final si la clase 4 se imparte al día siguiente: su paso 6 es opcional y reutiliza los manifiestos y el overlay.

La agenda suma 240 min. Los seis retos son parte del plan; si el grupo termina antes, se repasan los retos 5 y 6 o se ejecuta el HPA con más carga. Si sobra más tiempo, [`extra-60-min.md`](extra-60-min.md) tiene tres bloques de 20 min y [`lab/lab-3c.md`](lab/lab-3c.md) es otra hora de laboratorio con ConfigMap, Job/CronJob y cuotas.

## 00:00-00:10. Repaso y entornos

1. Pedir una frase por persona sobre la clase 2: red user-defined, `internal`, `service_healthy` o secreto como archivo.
2. Comprobar el entorno:

```bash
kind version
kubectl version --client
kubectl get nodes
```

3. Presentar el cambio de modelo: en Compose se declara un stack en un archivo y se arranca; en Kubernetes se declara el estado deseado y un controlador lo persigue. La aplicación no cambia.
4. Si alguien no tiene `kind`, emparejarlo o usar el clúster del instructor con un namespace propio. No instalar herramientas durante el bloque de repaso.

## 00:10-00:50. De Compose a Kubernetes

Recorrer las diapositivas con preguntas, sin leerlas:

- Pod como unidad de red y de programación.
- Deployment como estado deseado, con ReplicaSet y bucle de reconciliación.
- Service como nombre estable sobre pods que cambian.
- Ingress como regla que necesita un controlador.
- Readiness saca del tráfico; liveness reinicia.
- Requests reserva para el scheduler; limits corta el consumo.
- ConfigMap separa la configuración de la imagen; una variable exige reinicio y un archivo montado se actualiza solo.
- Job y CronJob terminan; Deployment y DaemonSet quedan corriendo.

Comparar con el compose que ya conocen: un servicio de Compose se parece a un Deployment con un contenedor, y los nombres de servicio se parecen a un Service. La diferencia es que aquí no hay un `up` que crea todo: hay objetos que se reconcilian.

Preguntas: ¿qué pasa si se borra un pod suelto?, ¿quién crea el pod nuevo?, ¿por qué un Service sin endpoints devuelve 503?, ¿qué decide el scheduler?

Checkpoint: los 6 distinguen Deployment de pod y readiness de liveness.

## 00:50-01:50. Laboratorio 3a, pasos 0 a 5

Todos trabajan desde `clase-03/lab`. Circular con esta tabla.

| Hora | Deberían estar en | Señal de que va bien |
|---|---|---|
| 00:55 | Pasos 0 y 1 | `kubectl get nodes` muestra el nodo `Ready` |
| 01:12 | Paso 2 | `kind load` terminó y la imagen aparece en el nodo |
| 01:29 | Paso 3 | Cuatro pods `1/1` y el PVC en `Bound` |
| 01:41 | Paso 4 | `curl localhost:18013/readyz` responde `ready` |
| 01:50 | Paso 5 | Escalaron a tres y volvieron a dos con `--current-replicas` |

Puntos donde se traba la gente:

- `kind create` falla por memoria. Cerrar contenedores y volver a intentar; no crear dos clústeres.
- `ImagePullBackOff`: la imagen no está en el nodo. `kind load docker-image tienda-api:3.0 --name curso`.
- PVC en `Pending`: comprobar que existe la StorageClass `standard`.
- La API en `CrashLoopBackOff`: mirar `kubectl logs` y la liveness. En `kind` el primer arranque puede tardar.
- `port-forward` no conecta: el pod no está listo o el puerto 18013 está ocupado.
- Un `kubectl apply` con el namespace mal escrito no falla: crea el objeto en `default`. Revisar siempre `-n tienda`.

Si a las 01:29 alguien sigue creando el clúster, sentarlo con una pareja que ya lo tenga y continuar desde el paso 3 en el clúster compartido. El objetivo es operar, no repetir la instalación.

## 01:50-02:00. Pausa

Comprobar que los 6 ven los cuatro pods `1/1` y el PVC `Bound`. Resolver ahora los clústeres a medias.

## 02:00-02:30. Operación y demos

Explicar el ciclo antes de ejecutar los demos:

- El Deployment compara réplicas deseadas con pods existentes.
- El rolling update crea y retira pods según `maxSurge` y `maxUnavailable`.
- El rollback vuelve a una revisión anterior.
- Readiness decide si un pod recibe tráfico; liveness decide si se reinicia.

Demos, en este orden:

```bash
cd clase-03/demos
./01-autoreparacion.sh
./02-rolling-update.sh
./03-probe-rota.sh
```

Qué señalar:

- El pod borrado no vuelve: aparece otro con nombre nuevo.
- Durante el rolling update hay pods de dos versiones a la vez.
- Con `maxUnavailable: 0` no se retira un pod viejo hasta que el nuevo está listo.
- En el demo 03 los pods nuevos quedan `0/1` sin reiniciarse y salen de los endpoints.
- La liveness mal puesta reinicia en bucle; la readiness mal puesta solo deja de enviar tráfico.

Los demos 04 a 06 (tipos de Service, initContainer y Job/CronJob/DaemonSet) no entran en los 30 minutos del bloque. Úsalos solo si el grupo llega adelantado; el laboratorio ya cubre Service, probes y actualización.

Si el grupo va justo, ejecutar solo el demo 01 y explicar el 03 con `kubectl describe`. El paso 8 del laboratorio ya rompe una probe.

## 02:30-03:15. Laboratorio 3b, pasos 6 a 9

| Hora | Deberían estar en | Señal de que va bien |
|---|---|---|
| 02:40 | Paso 6 | El Ingress responde con `Host: tienda.local` y sin `Host` devuelve 404 |
| 02:55 | Paso 7 | Vieron el `pause`, la versión 3.1 y los dos `undo` |
| 03:05 | Paso 8 | Los pods nuevos quedan `0/1`, sin reinicios, y los endpoints no los incluyen |
| 03:15 | Pasos 8 restaurado y 9 | El rollout termina, el HPA escala y quedan dos pods |

Errores de este bloque:

- 404 en el Ingress: el `Host` no coincide o falta la regla.
- 503 en el Ingress: el Service no tiene endpoints listos.
- El rollout no avanza: la probe nueva no pasa. `kubectl describe pod` y `rollout undo`.
- El controlador de Ingress no está listo: `kubectl -n ingress-nginx get pods`.
- El HPA no escala: `kubectl top pods` debe dar datos, no `<unknown>`.

Si el clúster no tiene Ingress por falta de red, aplicar el YAML predescargado o saltar el paso 6 y hacer el reto 4 en su variante de `targetPort`.

### Paso 9. HPA y métricas

Últimos 10 minutos del lab 3b, solo si `metrics-server` está instalado y `kubectl top pods` responde. Aplicar el HPA, generar carga y observar el escalado:

```bash
kubectl apply -f manifests/06-hpa.yaml
kubectl apply -f manifests/06-hpa.yaml
kubectl apply -f manifests/07-load.yaml
kubectl get hpa -n tienda -w
```

Al terminar, borrar la carga y el HPA, y esperar la ventana de estabilización:

```bash
kubectl delete pod load -n tienda
kubectl delete hpa api -n tienda
kubectl scale deployment/api --replicas=2 -n tienda
```

Borrar el HPA no devuelve las réplicas por sí solo: deja el Deployment en el último número que fijó. El `scale` lo deja en dos con certeza. Dejar el HPA puesto rompe el `lab-3c`: la cuota cuenta los pods que crea el escalado automático. El stack se queda en dos réplicas hasta el final del día.

Si no hay `metrics-server`, explicar el HPA sobre el manifiesto y dejar el paso 9 como deberes. No gastar 15 minutos instalándolo en clase.

## 03:15-03:50. Retos de diagnóstico

Presentar [`lab/retos-diagnostico.md`](lab/retos-diagnostico.md) y trabajar en parejas.

| Min | Reto | Qué se aprende |
|---|---|---|
| 03:15-03:21 | 1. Pod Pending | El scheduler no coloca un request que no cabe |
| 03:21-03:26 | 2. Service sin endpoints | El selector no coincide con las etiquetas |
| 03:26-03:34 | 3. Secreto viejo | Un rollout se queda a medias y la versión vieja sigue sirviendo |
| 03:34-03:40 | 4. Puerto del Ingress | El contrato entre Ingress y Service se rompe por un nombre |
| 03:40-03:45 | 5. OOMKilled | El límite de memoria mata el proceso y el pod reinicia |
| 03:45-03:50 | 6. Imagen inexistente | La imagen se distingue de un problema de recursos o del proceso |

Reglas para el instructor:

- El plan incluye los seis retos. Si surge una emergencia de tiempo, el recorte mínimo son los retos 1, 2 y 5; el resto queda como deberes.
- El reto 3 espera un rollout atascado. Enseñar a leer `kubectl get pods` y `describe` antes de tocar nada.
- Los retos 5 y 6 se revierten con `rollout undo`; comprobar que los recursos vuelven a `256Mi`.
- No permitir `kubectl delete namespace tienda` para "arreglar" un reto. Se pierde el PVC y el trabajo de la clase.
- Al terminar, restaurar con los manifiestos y comprobar que el rollout termina.

Checkpoint: cada pareja explica qué objeto estaba mal y qué comando lo confirmó.

## 03:50-04:00. Entregable y cierre

1. Recordar el entregable: salida de `kubectl get all`, `rollout history` y `undo`, captura del HPA y una frase sobre liveness y readiness.
2. Mostrar la rúbrica y el checklist.
3. Cerrar con una pregunta por persona: qué crea un pod nuevo, qué hace un Service, qué diferencia hay entre `Pending`, `CrashLoopBackOff`, `OOMKilled` e `ImagePullBackOff`, qué probe saca del tráfico.
4. Deberes: el reto que no se haya hecho, el paso 9 si no hubo `metrics-server` y `lab/lab-3c.md` para quien quiera más práctica.
5. Si la clase 4 es otro día, dejar el clúster en marcha y anotar su nombre. Si no, limpiar:

```bash
kind delete cluster --name curso
docker rmi tienda-api:3.0 tienda-api:3.1 2>/dev/null || true
```

No borrar `lab/manifests`: la clase 4 los reutiliza con un overlay de Kustomize.

## Versión de 8 horas

Para un día completo, la agenda está en [`plan-8h.md`](plan-8h.md). Mantiene el núcleo de 4 horas y agrega:

- `lab/lab-3c.md`: ConfigMap, Job/CronJob y cuotas (60 min).
- `lab/lab-3d.md`: Helm (60 min).
- `lab/lab-3e.md`: StatefulSet y almacenamiento (60 min).

Puntos de atención:

- El release `api-helm` convive con el Deployment `api`; el laboratorio de Helm no borra el stack.
- `lab-3e` trabaja en el namespace `stateful` y no toca `tienda`.
- Si el grupo va justo, el recorte es `lab-3e` como tarea; no recortes los retos.
- El entregable suma el chart validado, `helm history` con rollback y la salida de PVC del StatefulSet.
- Comprueba que Helm está instalado antes de la sesión. No lo instales durante el laboratorio.

## Si algo falla en vivo

| Síntoma | Qué hacer |
|---|---|
| `kind create` falla por memoria | Cerrar contenedores o subir la RAM de la VM; usar un clúster compartido |
| `ImagePullBackOff` | `kind load docker-image tienda-api:3.0 --name curso` |
| PVC en `Pending` | `kubectl get storageclass`; en `kind` debe existir `standard` |
| La API reinicia en bucle | Liveness agresiva o base no lista; `kubectl logs` y `describe` |
| Rollout atascado | La probe nueva no pasa; `rollout undo` y corregir |
| Ingress 404 | `Host` incorrecto o regla ausente |
| Ingress 503 | Service sin endpoints; `kubectl get endpoints api -n tienda` |
| `kubectl top` da `<unknown>` | `metrics-server` sin `--kubelet-insecure-tls` |
| `port-forward` no conecta | El pod no está listo o el puerto está ocupado |
| El grupo va atrasado | Saltar el paso 6 o el 9 y hacer los retos 1 y 2; el resto queda para casa |

## Después de la clase

- Revisar que el entregable incluya `rollout history` además de las capturas de pods.
- Anotar quién no terminó el clúster para el repaso de la clase 4.
- Si la clase 4 es al día siguiente, comprobar que el clúster sigue vivo; la clase 4 cargará su propia imagen `tienda-api:4.0`.
- Si cambiaste algo del material, actualizar `slides.md` y las capturas de resultados medidos.
