# Clase 3: orquestación y Kubernetes con `kind`

**Duración:** 4 h u 8 h · **Participantes:** 6 · **Requisitos:** Docker funcionando, `kind` 0.24+, `kubectl` 1.31+, Helm 3.16+ para el plan de 8 h, 8 GB de RAM en el equipo

## Materiales

| Archivo | Para qué |
|---|---|
| `slides.md` | Diapositivas (Marp). Renderizar con `marp slides.md -o slides.pdf` o proyectar el Markdown |
| `slides.pptx` | Presentación lista para proyectar (exportada de `slides.md`) |
| `slides.pdf` | Respaldo para proyectar sin PowerPoint, útil si el equipo va justo de memoria |
| `plan-8h.md` | Agenda de día completo con los tres laboratorios extra |
| `preparar-clase.sh` | Deja el clúster, el stack, Ingress y métricas listos de una vez |
| `../modo-bajo-consumo.md` | Ajustes si el equipo que proyecta también corre el clúster |
| `extra-60-min.md` | Tres bloques de 20 min si el grupo termina antes |
| `guia-docente.md` | Guion de sesión: preparación, tiempos, checkpoints y planes B |
| `lab/guia-paso-a-paso.md` | Guía del alumno con resultados medidos y diagnóstico |
| `lab/retos-diagnostico.md` | Seis averías cronometradas sobre el clúster |
| `lab/lab-3c.md` | Laboratorio de 60 min: ConfigMap, Job/CronJob y cuotas |
| `lab/lab-3d.md` | Laboratorio de 60 min: empaquetar la API con Helm |
| `lab/lab-3e.md` | Laboratorio de 60 min: StatefulSet y almacenamiento |
| `lab/extra/` | Manifiestos del lab 3c |
| `lab/helm/tienda/` | Chart de la API para el lab 3d |
| `lab/statefulset/` | Manifiestos de Postgres como StatefulSet para el lab 3e |
| `lab/kind-config.yaml` | Clúster de un nodo con los puertos del Ingress |
| `lab/manifests/` | Namespace, Secret, Postgres, Redis, API, Ingress y HPA |
| `lab/README.md` | Índice del lab y arranque rápido |
| `demos/01-autoreparacion.sh` | Borrar un pod y ver el reemplazo |
| `demos/02-rolling-update.sh` | Actualizar la versión y volver atrás |
| `demos/03-probe-rota.sh` | Romper readiness y observar el tráfico |
| `demos/04-tipos-service.sh` | ClusterIP, headless y NodePort |
| `demos/05-initcontainer.sh` | Un initContainer espera a Postgres |
| `demos/06-tipos-workload.sh` | Job, CronJob y DaemonSet |
| `evaluacion/rubrica-clase-03.md` | Rúbrica del entregable |
| `recursos/checklist-kubernetes.md` | Checklist imprimible |

## Cómo usar este material

**Instructor**

1. Crea el clúster y aplica los manifiestos antes de clase. El primer `kind create` descarga la imagen del nodo y tarda varios minutos.
2. Pre-descarga `busybox:1.36` y las imágenes del stack. Si algún participante no tiene salida a Internet, guarda también el YAML de `ingress-nginx` y de `metrics-server`.
3. Proyecta `slides.pptx` y sigue `guia-docente.md` para los tiempos, los checkpoints y los planes B.
4. Ten presente el límite de memoria: un clúster de `kind` con Ingress y métricas pide cerca de 2 GB por participante. En equipos de 8 GB conviene cerrar Docker Desktop y otros contenedores.
5. La demo de HPA necesita `metrics-server` con `--kubelet-insecure-tls`. Sin ese patch, `kubectl top` devuelve `<unknown>`.
6. Usa `lab/retos-diagnostico.md` en el bloque de cierre. Si no hay Ingress, cambia el reto 4 por la variante de `targetPort`.
7. Si el grupo termina antes, `extra-60-min.md` tiene tres bloques de 20 min: HPA con métricas, depuración de pods y rolling update contra Recreate. `lab/lab-3c.md` es otra hora de laboratorio con ConfigMap, Job/CronJob y cuotas; se puede usar como reserva o como tarea para casa.
8. Para un día completo, sigue `plan-8h.md`: el núcleo de 4 h más `lab-3c`, `lab-3d` (Helm) y `lab-3e` (StatefulSet). Instala Helm antes de la sesión y prueba los tres laboratorios en el clúster de referencia.

**Alumno**

1. Sigue `lab/guia-paso-a-paso.md` en orden. El clúster se crea una vez y se reutiliza.
2. No avances del paso 3 sin ver los cuatro pods `1/1` y el PVC `Bound`.
3. Usa `recursos/checklist-kubernetes.md` antes de entregar.

## Agenda (240 min)

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:10 | Repaso de la clase 2 y dudas | `docker compose ps`, preguntas del lab 2 |
| 00:10-00:50 | De Compose a Kubernetes: pods, Deployments, Services, probes, recursos, configuración y workloads | `slides.md` |
| 00:50-01:50 | Lab 3a: crear el clúster, cargar la imagen, desplegar y probar | `lab/guia-paso-a-paso.md` pasos 0-5 |
| 01:50-02:00 | Pausa | sin material |
| 02:00-02:30 | Operación: auto-reparación, rolling updates, rollback, readiness frente a liveness | `slides.md` + `demos/` |
| 02:30-03:15 | Lab 3b: Ingress, actualización con pausa y rollback, probe rota y HPA | `lab/guia-paso-a-paso.md` pasos 6-9 |
| 03:15-03:50 | Retos de diagnóstico en parejas | `lab/retos-diagnostico.md` |
| 03:50-04:00 | Entregable y cierre | `evaluacion/rubrica-clase-03.md` |

Para 8 h, `plan-8h.md` reordena el día, agrega `lab-3c`, `lab-3d` y `lab-3e` y deja los retos al final, con pausas y comida.

## Conceptos clave

- **Estado deseado.** Un Deployment declara réplicas y plantilla; el controlador compara y actúa. No hay pasos imperativos.
- **Pod contra contenedor.** El pod es la unidad de red y de programación. Un pod suelto no se repara; un Deployment sí.
- **Service.** Da un nombre y una IP estable a un conjunto de pods que cambian. Sin endpoints listos, el Service no entrega tráfico.
- **Ingress.** Solo es una regla; necesita un controlador que la implemente. En `kind` se publica por `extraPortMappings`.
- **readiness frente a liveness.** Readiness saca del tráfico sin reiniciar. Liveness reinicia el proceso.
- **requests y limits.** Requests reserva para el scheduler; limits corta el consumo. El HPA calcula sobre los requests.
- **ConfigMap y Secret.** Separan la configuración de la imagen. La variable se lee al arrancar; el archivo montado se sincroniza solo.
- **Cuota.** El `ResourceQuota` limita el namespace y rechaza pods antes de crearlos; el `LimitRange` pone recursos por defecto.
- **Helm.** Un chart es la plantilla y un release es una instalación con historial. `values.yaml` evita editar YAML por entorno.
- **StatefulSet.** Da nombres ordinales, DNS propio y un PVC por réplica. Escalar no replica los datos.
- **Imagen local.** `kind load docker-image` evita montar un registry. El nombre y la etiqueta deben coincidir exactamente.

## Guion de demos

1. **Auto-reparación** (`demos/01-autoreparacion.sh`): borrar un pod de la API y ver el reemplazo en segundos. Preguntar: *¿quién creó el pod nuevo?*
2. **Rolling update** (`demos/02-rolling-update.sh`): cambiar imagen y versión, comprobar que la respuesta cambia y volver con `rollout undo`. Preguntar: *¿qué garantiza `maxUnavailable: 0`?*
3. **Probe rota** (`demos/03-probe-rota.sh`): apuntar readiness a una ruta inexistente y ver pods `0/1` fuera de los endpoints. Preguntar: *¿por qué no se reinician?*
4. **Tipos de Service** (`demos/04-tipos-service.sh`): comparar ClusterIP, headless y NodePort, y ver qué devuelve el DNS en cada caso.
5. **initContainer** (`demos/05-initcontainer.sh`): un pod que no arranca hasta que Postgres acepta conexiones. Preguntar: *¿en qué se diferencia de un `startupProbe`?*
6. **Tipos de workload** (`demos/06-tipos-workload.sh`): Job, CronJob y DaemonSet en una sola pasada, con limpieza al final.

## Errores comunes y cómo resolverlos

| Síntoma | Causa | Solución |
|---|---|---|
| `ImagePullBackOff` | La imagen no está en el nodo | `kind load docker-image tienda-api:3.0 --name curso` |
| `kind create` falla por memoria | Menos de 4 GB libres | Cierra contenedores o sube la RAM de la VM |
| PVC en `Pending` | No hay StorageClass por defecto | `kubectl get storageclass`; en `kind` debe existir `standard` |
| La API reinicia en bucle | Liveness o startup demasiado estrictas | Revisa `startupProbe` y `kubectl logs` |
| Rollout atascado | La probe nueva no pasa | `kubectl describe pod`, `kubectl rollout undo` |
| Ingress devuelve 404 | Falta el `Host` correcto | `curl -H 'Host: tienda.local'` o `/etc/hosts` |
| Ingress devuelve 503 | Service sin endpoints | `kubectl get endpoints api` |
| Un pod no aparece | La cuota lo rechazó | `kubectl describe quota` y los eventos con `exceeded quota` |
| Una variable del ConfigMap no cambia | Se leyó al arrancar el contenedor | `kubectl rollout restart deployment/api` |
| `kubectl top` da `<unknown>` | metrics-server sin el patch TLS | Añadir `--kubelet-insecure-tls` |
| `port-forward` no conecta | El pod no está listo | `kubectl get pods -n tienda` |

## Evaluación

- Entregable: manifiestos aplicados, salida de `kubectl get all`, `rollout history`, rollback y captura del HPA.
- Rúbrica: `evaluacion/rubrica-clase-03.md` (10 % del curso).
- Demo oral (3 min): explicar auto-reparación, diferencia entre liveness y readiness, y qué hace un Service.
- En la versión de 8 h, sumar el chart validado con `helm lint`, `helm history` con rollback y la salida de PVC del StatefulSet.

## Preparación del aula

Desde la raíz del repositorio:

```bash
docker pull busybox:1.36
docker pull postgres:16-alpine
docker pull redis:7-alpine
docker pull nginx:1.27-alpine
docker build -t tienda-api:3.0 clase-02/lab/app

# El clúster se crea una vez por alumno o uno compartido por pareja
kind create cluster --config clase-03/lab/kind-config.yaml --wait 120s

# Comprobar que los puertos del Ingress están libres
ss -ltn | grep -E '18020|18443' || echo "puertos libres"
```

Cada participante levanta su clúster de `kind`, que pide cerca de 2 GB de RAM. Si un equipo no llega, comparte el clúster de un compañero con namespaces por pareja (`tienda-ana`, `tienda-luis`). Los manifiestos usan `tienda`; cambia el namespace o usa `kubectl -n` con el que corresponda.
