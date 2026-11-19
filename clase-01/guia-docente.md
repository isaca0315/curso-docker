# Guía del docente: clase 1

Guion de sesión para las 4 horas. Los tiempos son relativos al inicio (00:00). La guía del alumno es [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md) y se sigue en paralelo; el instructor comparte pantalla.

## Modalidad virtual

Cada participante ejecuta los laboratorios en su equipo y sigue la guía en paralelo. Las imágenes base se descargan antes de la sesión en cada equipo para no depender de la conexión durante los builds.

**Material que conviene tener abierto:** [`slides.pptx`](slides.pptx), [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md), [`evaluacion/rubrica-clase-01.md`](evaluacion/rubrica-clase-01.md) y una copia impresa de [`recursos/checklist-dockerfile.md`](recursos/checklist-dockerfile.md) por participante.

## Antes de la clase

### El día anterior

Preconstruir las cuatro imágenes y descargar las bases. Los demos 01 y 02 abortan si no existe `tienda-api:optimized`, y en la agenda van antes del laboratorio:

```bash
cd clase-01/lab/app
docker build -f Dockerfile.naive -t tienda-api:naive .
docker build -t tienda-api:optimized .
docker build -f Dockerfile.alpine -t tienda-api:alpine .
docker build -f Dockerfile.distroless -t tienda-api:distroless .

docker pull python:3.12
docker pull python:3.12-slim
docker pull python:3.12-alpine
docker pull python:3.11-slim
docker pull alpine:3.20
docker pull gcr.io/distroless/python3-debian12:nonroot
```

### Quince minutos antes

- `docker run --rm hello-world` y `docker info --format '{{.CgroupVersion}}'`. Si dice `1`, los archivos del demo de límites cambian y hay que avisarlo.
- Comprobar que los puertos 18000, 18001, 18002, 18003, 18090 y 18091 estén libres.
- Ejecutar una vez los tres demos para confirmar que funcionan en el aula.
- Cada participante trabaja en su equipo, así que los nombres y puertos fijos no chocan. Solo si dos personas comparten host hay que asignar un rango de puertos (`18000 + 10n`) y un prefijo de nombre.

## Agenda

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:20 | Bienvenida, diagnóstico y entornos | `docker version`, `docker run hello-world` |
| 00:20-01:00 | Arquitectura | `slides.md` + `demos/01-arquitectura.sh` |
| 01:00-01:45 | Configuración | `slides.md` + `demos/configuracion-daemon.md` |
| 01:45-01:55 | Pausa | |
| 01:55-02:15 | Construcción de imágenes | `slides.md` |
| 02:15-03:15 | Laboratorio, pasos 1 a 6 | `lab/guia-paso-a-paso.md` |
| 03:15-03:25 | Pausa | |
| 03:25-04:00 | Reto, distroless, entregable y cierre | pasos 7 y 8 + `Dockerfile.alpine` + `Dockerfile.distroless` |

## 00:00-00:20. Bienvenida y diagnóstico

1. Presentar el hilo del curso: `tienda-api` es la misma aplicación en las cuatro clases.
2. Cada participante ejecuta:

```bash
docker version
docker info --format 'Driver: {{.Driver}} | Cgroup: {{.CgroupVersion}} | Logs: {{.LoggingDriver}}'
docker run --rm hello-world
df -h .
```

3. No avanzar hasta que los 6 tengan cliente y servidor en `docker version`.
4. Errores de este bloque: solo aparece el cliente (daemon apagado), `permission denied` en el socket (falta el grupo `docker`), Docker Desktop cerrado, menos de 4 GB libres.
5. Cerrar con la pregunta que ordena la clase: si el contenedor no es una VM, ¿qué comparte y qué aísla?

## 00:20-01:00. Arquitectura

Recorrer las diapositivas con preguntas, sin leerlas. El orden es contenedor frente a VM, CLI, daemon, containerd, runc, namespaces, cgroups, capas y OCI.

Demo en vivo:

```bash
cd clase-01/demos
./01-arquitectura.sh
```

Qué señalar:

- El PID del contenedor es un proceso normal del host.
- Los shims de containerd siguen ahí aunque muera el proceso principal.
- Los namespaces cambian entre el host y el interior del contenedor.
- `docker diff` solo muestra lo escrito en ejecución: la capa de escritura es efímera.
- `docker history` muestra las capas de la imagen.

Preguntas para el grupo: ¿dónde está el kernel?, ¿qué pasa con la capa escribible al borrar el contenedor?, ¿por qué importa el shim si se reinicia el daemon?

Checkpoint: los 6 responden al menos una pregunta.

## 01:00-01:45. Configuración

Seguir [`demos/configuracion-daemon.md`](demos/configuracion-daemon.md).

Inspección sin cambios:

```bash
docker context ls
docker system df
docker info --format 'Root: {{.DockerRootDir}}'
```

Rotación de logs por contenedor, que no requiere tocar el daemon:

```bash
docker run -d --name logs-demo \
  --log-driver json-file --log-opt max-size=1m --log-opt max-file=2 \
  alpine:3.20 sh -c 'while true; do echo linea; sleep 0.01; done'
sleep 15
docker inspect -f '{{.HostConfig.LogConfig}}' logs-demo
docker inspect -f '{{.LogPath}}' logs-demo
docker rm -f logs-demo
```

Después mostrar [`demos/daemon.json`](demos/daemon.json) y explicar cada clave. El cambio real de `/etc/docker/daemon.json` solo se hace en una VM de práctica, nunca en el equipo personal de un alumno. Si nadie tiene VM, se salta el paso 4 del documento y se explica sobre el archivo.

Cerrar con rootless, contextos remotos y por qué copiar el socket de Docker equivale a dar root.

## 01:45-01:55. Pausa

Aprovechar para comprobar que todos pueden construir:

```bash
cd clase-01/lab/app
docker build -f Dockerfile.naive -t prueba-naive .
docker image rm prueba-naive
```

Si alguien no puede, resolverlo ahora y no durante el laboratorio.

## 01:55-02:15. Construcción de imágenes

Diapositivas de Dockerfile: anatomía, orden y caché, multi-stage con etapa de test, elección de base, `.dockerignore`, usuario no root y antipatrones.

Dejar una sola idea antes del laboratorio: el orden de las instrucciones decide qué se reutiliza. `COPY requirements.txt` y `RUN pip install` van antes de `COPY . .`.

No mostrar todavía el Dockerfile optimizado completo. Se compara en el paso 4.

## 02:15-03:15. Laboratorio, pasos 1 a 6

Todos trabajan desde `clase-01/lab/app`. Circular con esta tabla en la mano.

| Hora | Deberían estar en | Señal de que va bien |
|---|---|---|
| 02:20 | Paso 1, imagen naive | `tienda-naive` en `Up` y los tres endpoints responden |
| 02:30 | Paso 2, mediciones | 1,63 GB, usuario root, capa gigante en `docker history` |
| 02:42 | Paso 3, Dockerfile escrito | Tres etapas, `requirements.txt` antes de `COPY . .` |
| 02:52 | Paso 4, optimizada | 205 MB, `uid=10001(appuser)`, healthcheck `healthy`, test ejecutado |
| 03:02 | Paso 5, caché | naive reinstala pip, optimizada solo recopia `app.py` |
| 03:10 | Paso 6, límites | `cpu.max` 50000/100000, `memory.low` 64m, `pids.max` 100, OOM con exit 137 |

Puntos donde se traba la gente:

- El healthcheck tarda hasta 60 s en pasar de `starting` a `healthy`. Que no borren el contenedor antes.
- En el paso 5 hay que restaurar `app.py`. Si alguien corta el comando, queda el comentario agregado.
- El OOM necesita unos segundos. Esperar `OOMKilled=true` antes de concluir.
- En Docker Desktop los límites por contenedor se ven mejor por CLI. La interfaz solo ajusta los recursos de la VM completa.

Si a las 03:05 alguien sigue en el paso 3, sentarlo con un compañero y que continúe desde el paso 4 con la imagen ya construida. No frenar al grupo.

## 03:15-03:25. Pausa

## 03:25-04:00. Reto, distroless y cierre

1. 03:25-03:35. Enunciar el reto: menos de 100 MB, tres endpoints, usuario no root y sin secretos (paso 7.1). Dar 10 minutos y prohibir mirar `Dockerfile.alpine` durante ese rato.
2. 03:35-03:42. Construir la referencia y verificar:

```bash
docker build -f Dockerfile.alpine -t tienda-api:alpine .
docker run -d --name tienda-alp -p 18002:8000 tienda-api:alpine
curl -s localhost:18002/healthz
docker exec tienda-alp id
```

Esperado: 79 MB, `uid=10001`, tres endpoints.

3. 03:42-03:47. Variante distroless. Se puede construir en vivo; los alumnos no necesitan escribirla:

```bash
docker build -f Dockerfile.distroless -t tienda-api:distroless .
docker run -d --name tienda-dis -p 18003:8000 tienda-api:distroless
curl -s localhost:18003/healthz
docker inspect --format 'User={{.Config.User}} Health={{.State.Health.Status}}' tienda-dis
docker exec tienda-dis sh
```

Esperado: 85 MB, `User=65532`, `healthy`, y el último comando falla porque no hay shell. Cerrar con el costo: no se puede depurar dentro, el builder debe usar la misma versión de Python que la base y pesa más que alpine.

4. 03:47-03:56. Entregable: Dockerfile multi-stage funcionando y el informe de 5 líneas del paso 8.1 con mediciones reales. Mostrar la rúbrica y el checklist.
5. 03:56-04:00. Cierre oral: una pregunta por persona, distintas. Namespaces, cgroups, capas, multi-stage, caché y OOM. Distroless queda como pregunta extra si sobra tiempo.
6. Limpieza, si queda tiempo o para casa:

```bash
docker rm -f tienda-naive tienda-opt tienda-alp tienda-dis 2>/dev/null || true
docker rmi tienda-api:naive tienda-api:optimized tienda-api:alpine tienda-api:distroless 2>/dev/null || true
```

Avisar que en la clase 2 se reutiliza `lab/app`: no borrar el directorio, solo las imágenes y los contenedores.

## Si algo falla en vivo

| Síntoma | Qué hacer |
|---|---|
| `bind: address already in use` | `docker rm -f` del contenedor viejo o cambiar el puerto de la izquierda |
| La imagen optimizada pesa casi lo mismo | Revisar `COPY --from`; se copió el builder entero |
| El build no usa caché | `COPY . .` quedó antes de `pip install` |
| `exec format error` en alpine | Se compiló en glibc y se ejecuta en musl |
| `permission denied` al escribir | Es esperado con `USER appuser`; escribir en `/tmp` |
| El demo 01 o 02 dice que falta la imagen | No se preconstruyó `tienda-api:optimized` |
| El build falla en la etapa `test` | La app está rota o falta una ruta; revisar el error con `--progress=plain` |
| `docker exec <c> sh` falla en distroless | Es esperado; usar `docker inspect` o ejecutar Python directamente |
| El grupo va atrasado en el laboratorio | Emparejar y continuar desde la imagen ya construida, no reiniciar el paso |

## Después de la clase

- Revisar que los entregables incluyan mediciones reales y no solo el Dockerfile.
- Anotar quién quedó atrasado para el repaso de la clase 2.
- Si sobraron 40 minutos o el grupo pidió ver cómo se arranca la imagen sin flags, usar `extra-compose/`: deja el stack `api + proxy` sano y sirve de puente a la clase 2.
- Si cambiaste algo del material, actualizar `slides.md` y volver a exportar `slides.pptx`.
