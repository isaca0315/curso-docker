# Modo de bajo consumo

Guía para cuando el equipo que proyecta la clase es también el que corre el clúster. No hay servidor aparte: en la misma máquina conviven la videollamada, las diapositivas, Docker Desktop y `kind`.

El material se probó en un equipo de 8 GB con el clúster, el stack completo y el navegador abierto. Alcanza si cierras lo que no estés usando.

## Qué consume qué

| Componente | Consumo aproximado |
|---|---|
| Stack de la clase 2 (`tienda-*`) | menos de 100 MB |
| Nodo de `kind` con `kube-system` | 500 a 800 MB |
| `ingress-nginx` | 100 a 150 MB |
| `metrics-server` | 50 a 100 MB |
| Stack `tienda` en Kubernetes | 200 a 300 MB |
| Navegador con videollamada y diapositivas | 1 a 2 GB |

El peso no está en los contenedores de la aplicación. Está en la máquina virtual de Docker Desktop y en el navegador. Por eso las medidas que más rinden son ajustar la VM, cerrar stacks que no se usan y no duplicar el clúster.

## Antes de la sesión

Docker Desktop:

- 2 CPU y 4 GB de memoria para la VM. Con menos de 4 GB, `kind` y el stack compiten por memoria.
- Kubernetes de Docker Desktop desactivado. El curso usa `kind`; tener los dos es duplicar el plano de control.
- Cerrar Docker Desktop al terminar cada clase si no vas a dejar el clúster para el día siguiente.

En Linux con Docker Engine no hay VM que ajustar: el límite lo pone el equipo. Ahí lo que rinde es cerrar aplicaciones y no duplicar el clúster.

Liberar el equipo:

```bash
# Stacks que no se usan en esta clase
docker ps --format '{{.Names}}'
(cd clase-02/lab && docker compose down)   # solo si no lo estás usando

# Qué está consumiendo la memoria del escritorio
ps aux --sort=-%mem | head -12

# Espacio en disco, no memoria: la caché de build crece mucho
docker builder prune -f
free -h
```

Cierra lo que no sea la videollamada ni las diapositivas: pestañas de más, Slack, Spotify, servidores de desarrollo y editores con muchos procesos.

No uses `docker system prune -a` antes de la clase: borra las imágenes que necesitas y obliga a descargarlas en vivo.

Deja las imágenes descargadas y la aplicación construida:

```bash
docker pull kindest/node:v1.31.0
docker pull busybox:1.36
docker pull postgres:16-alpine
docker pull redis:7-alpine
```

Para la clase 3, construye `tienda-api:3.0` una vez antes de la sesión. Así el `docker build` del laboratorio reutiliza la caché y no descarga capas en vivo.

Prueba el equipo en las condiciones reales: abre la videollamada, comparte pantalla y recién entonces crea el clúster. Si el equipo aguanta así, aguanta en clase:

```bash
cd clase-03/lab
kind create cluster --config kind-config.yaml --wait 180s
free -h
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}'
kind delete cluster --name curso
```

**Meta:** con el clúster arriba y la videollamada abierta, deben quedar 1.5 GB libres como mínimo.

El script `clase-03/preparar-clase.sh` hace la preparación completa y avisa si falta memoria o un puerto. Si el equipo se reinicia, se vuelve a ejecutar y deja lo mismo.

## Durante la clase

- Un solo clúster. Antes de empezar: `kind get clusters`. Si aparece otro, bórralo.
- El HPA tiene tope de 3 réplicas en `manifests/06-hpa.yaml`. Con 6 alumnos cada uno en su equipo no hace falta más, y en el equipo que proyecta cada réplica extra es memoria y CPU que le quitas a la llamada. El pod que genera carga también lleva `requests` y `limits` en la guía.
- `preparar-clase.sh` pone un techo de 3.5 GB de memoria al contenedor del nodo (`docker update --memory 3500m`). En un equipo de 8 GB, si un laboratorio se desboca, el OOM ocurre dentro de `kind` y no en el escritorio. Se vuelve a aplicar cada vez que corres el script. En Docker Desktop el techo se pone en la VM, no aquí.
- El escalado manual del paso 5 llega a 3 réplicas, no a 4. Es suficiente para ver cambiar pods y endpoints.
- `metrics-server` solo si vas a hacer el bloque de HPA. Después se puede borrar:

  ```bash
  kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  ```

- El Ingress solo hace falta en el paso 6 y en el lab 3b. Si el equipo va justo, salta el controlador y usa `kubectl port-forward -n tienda svc/api 18013:8000`. El resto del laboratorio funciona igual.
- En el lab 3d, la API original se deja en una réplica mientras corre `api-helm`. El propio laboratorio lo indica y lo restaura al final.
- No renderices las diapositivas con Marp durante la clase. Usa `slides.pptx` o el PDF ya generado (`clase-03/slides.pdf`): `npx` levanta Node y un navegador headless solo para exportar.
- No dejes terminales con `kubectl get pods -w` ni `kubectl top` en bucle. Consumen poco, pero suman y distraen.

## Clase 4

El clúster de la clase 3 solo hace falta en el bloque de Kustomize. Puedes tenerlo apagado mientras construyes y escaneas imágenes:

```bash
kind delete cluster --name curso
# bloque de Dockerfile, gates y Trivy
cd clase-03/lab && kind create cluster --config kind-config.yaml --wait 180s
```

Trivy descarga una base de datos de CVEs en el primer escaneo y puede llegar a 500 MB de memoria. Ejecuta un escaneo a la vez y usa los informes guardados como respaldo. El demo ya usa `--scanners vuln` y `--quiet`, que es el modo más liviano.

## Si aun así no alcanza

- El clúster solo tiene que existir durante el laboratorio. Las diapositivas y la explicación no lo necesitan: créalo al entrar al bloque y bórralo al salir.
- Las guías traen los resultados esperados de cada comando. Si el equipo no responde, muestra la salida documentada y sigue con el concepto; el alumno ejecuta en su propio equipo.
- Graba una vez el laboratorio completo y úsalo como respaldo si la sesión en vivo se cae. Un video de 10 minutos cubre el riesgo de quedarte sin equipo.
- Recorta primero los demos 04 a 06 y el lab 3e. Los retos y el núcleo de 4 horas no se recortan.
