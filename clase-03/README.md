# Clase 3: orquestación y Kubernetes con `kind`

**Duración:** 4 h · **Participantes:** 6 · **Requisitos:** Docker funcionando, `kind` 0.24+ y `kubectl` 1.31+, 4 GB de RAM libres

## Materiales

| Archivo | Para qué |
|---|---|
| `slides.md` | Diapositivas (Marp). Renderizar con `marp slides.md -o slides.pdf` o proyectar el Markdown |
| `slides.pptx` | Presentación lista para proyectar (exportada de `slides.md`) |
| `extra-60-min.md` | Tres bloques de 20 min si el grupo termina antes |
| `guia-docente.md` | Guion de sesión: preparación, tiempos, checkpoints y planes B |
| `lab/guia-paso-a-paso.md` | Guía del alumno con resultados medidos y diagnóstico |
| `lab/retos-diagnostico.md` | Cuatro averías cronometradas sobre el clúster |
| `lab/kind-config.yaml` | Clúster de un nodo con los puertos del Ingress |
| `lab/manifests/` | Namespace, Secret, Postgres, Redis, API, Ingress y HPA |
| `lab/README.md` | Índice del lab y arranque rápido |
| `demos/01-autoreparacion.sh` | Borrar un pod y ver el reemplazo |
| `demos/02-rolling-update.sh` | Actualizar la versión y volver atrás |
| `demos/03-probe-rota.sh` | Romper readiness y observar el tráfico |
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
7. Si el grupo termina antes, `extra-60-min.md` tiene tres bloques de 20 min: HPA con métricas, depuración de pods y rolling update contra Recreate.

**Alumno**

1. Sigue `lab/guia-paso-a-paso.md` en orden. El clúster se crea una vez y se reutiliza.
2. No avances del paso 3 sin ver los cuatro pods `1/1` y el PVC `Bound`.
3. Usa `recursos/checklist-kubernetes.md` antes de entregar.

## Agenda (240 min)

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:15 | Repaso de la clase 2 y dudas | `docker compose ps`, preguntas del lab 2 |
| 00:15-00:55 | De Compose a Kubernetes: pods, Deployments, Services, Ingress, probes, requests y limits | `slides.md` |
| 00:55-01:50 | Lab 3a: crear el clúster, cargar la imagen, desplegar y probar | `lab/guia-paso-a-paso.md` pasos 0-5 |
| 01:50-02:00 | Pausa | sin material |
| 02:00-02:40 | Operación: auto-reparación, rolling updates, rollback, readiness frente a liveness | `slides.md` + `demos/` |
| 02:40-03:15 | Lab 3b: Ingress, actualización sin caída y probe rota | `lab/guia-paso-a-paso.md` pasos 6-8 |
| 03:15-03:25 | HPA con carga, si el clúster tiene `metrics-server` | `lab/guia-paso-a-paso.md` paso 9 |
| 03:25-03:50 | Retos de diagnóstico en parejas | `lab/retos-diagnostico.md` |
| 03:50-04:00 | Entregable y cierre | `evaluacion/rubrica-clase-03.md` |

## Conceptos clave

- **Estado deseado.** Un Deployment declara réplicas y plantilla; el controlador compara y actúa. No hay pasos imperativos.
- **Pod contra contenedor.** El pod es la unidad de red y de programación. Un pod suelto no se repara; un Deployment sí.
- **Service.** Da un nombre y una IP estable a un conjunto de pods que cambian. Sin endpoints listos, el Service no entrega tráfico.
- **Ingress.** Solo es una regla; necesita un controlador que la implemente. En `kind` se publica por `extraPortMappings`.
- **readiness frente a liveness.** Readiness saca del tráfico sin reiniciar. Liveness reinicia el proceso.
- **requests y limits.** Requests reserva para el scheduler; limits corta el consumo. El HPA calcula sobre los requests.
- **Imagen local.** `kind load docker-image` evita montar un registry. El nombre y la etiqueta deben coincidir exactamente.

## Guion de demos

1. **Auto-reparación** (`demos/01-autoreparacion.sh`): borrar un pod de la API y ver el reemplazo en segundos. Preguntar: *¿quién creó el pod nuevo?*
2. **Rolling update** (`demos/02-rolling-update.sh`): cambiar imagen y versión, comprobar que la respuesta cambia y volver con `rollout undo`. Preguntar: *¿qué garantiza `maxUnavailable: 0`?*
3. **Probe rota** (`demos/03-probe-rota.sh`): apuntar readiness a una ruta inexistente y ver pods `0/1` fuera de los endpoints. Preguntar: *¿por qué no se reinician?*

## Errores comunes y cómo resolverlos

| Síntoma | Causa | Solución |
|---|---|---|
| `ImagePullBackOff` | La imagen no está en el nodo | `kind load docker-image tienda-api:3.0 --name curso` |
| `kind create` falla por memoria | Menos de 4 GB libres | Cierra contenedores o sube la RAM de la VM |
| PVC en `Pending` | No hay StorageClass por defecto | `kubectl get storageclass`; en `kind` debe existir `standard` |
| La API reinicia en bucle | Liveness demasiado agresiva | Sube `initialDelaySeconds` y mira `kubectl logs` |
| Rollout atascado | La probe nueva no pasa | `kubectl describe pod`, `kubectl rollout undo` |
| Ingress devuelve 404 | Falta el `Host` correcto | `curl -H 'Host: tienda.local'` o `/etc/hosts` |
| Ingress devuelve 503 | Service sin endpoints | `kubectl get endpoints api` |
| `kubectl top` da `<unknown>` | metrics-server sin el patch TLS | Añadir `--kubelet-insecure-tls` |
| `port-forward` no conecta | El pod no está listo | `kubectl get pods -n tienda` |

## Evaluación

- Entregable: manifiestos aplicados, salida de `kubectl get all`, `rollout history`, rollback y captura del HPA.
- Rúbrica: `evaluacion/rubrica-clase-03.md` (10 % del curso).
- Demo oral (3 min): explicar auto-reparación, diferencia entre liveness y readiness, y qué hace un Service.

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
