# Guía paso a paso: Lab 1, de 1,6 GB a 79 MB

| Dato | Valor |
|---|---|
| Duración | 60 min (pasos 1-6) + 20 min (reto, paso 7) + 15 min (entregable, paso 8) |
| Directorio de trabajo | `clase-01/lab/app` |
| Imagen de partida | `python:3.12` (~1 GB de descarga la primera vez) |
| Docker | Engine 24 o superior (CLI) o Docker Desktop 4.30 o superior |
| Disco libre recomendado | 4 GB |
| Entregable | `Dockerfile` multi-stage + informe de 5 líneas |

## Qué vas a aprender

Al terminar serás capaz de:

1. Explicar qué pasa desde `docker build` hasta que la app responde.
2. Medir una imagen y saber **dónde** está su peso.
3. Escribir un `Dockerfile` multi-stage con usuario sin privilegios.
4. Predecir qué capas se invalidan al cambiar código o dependencias.
5. Aplicar límites de CPU/memoria y reconocer un OOM kill.
6. Reducir una imagen de 1,63 GB a menos de 100 MB y explicar el trade-off.

## Mapa de pasos

| Paso | Qué haces | Tiempo |
|---|---|---|
| 0 | Verificar el entorno | 5 min |
| 1 | Construir y ejecutar la imagen ingenua | 10 min |
| 2 | Medir tamaño, capas y usuario | 8 min |
| 3 | Escribir el `Dockerfile` multi-stage con test | 12 min |
| 4 | Construir, comparar y ejecutar con límites | 10 min |
| 5 | Experimento de caché | 10 min |
| 6 | Límites de CPU/memoria y OOM | 10 min |
| 7 | Reto: bajar de 100 MB | 20 min |
| 8 | Entregable y cierre | 15 min |

## Convenciones

- Todos los comandos se ejecutan desde `clase-01/lab/app` salvo que se indique otra cosa.
- Los nombres de contenedor (`tienda-naive`, `tienda-opt`, `tienda-alp`) son únicos a propósito para poder borrarlos sin tocar otros.
- Los puertos del host son 18000, 18001 y 18002. Si están ocupados, cambia solo el número de la izquierda (`-p 18100:8000`).
- Los comandos están en bash. En PowerShell, el Apéndice D traduce las diferencias.
- Los tamaños son los medidos en Linux x86-64 con Docker 29. En macOS/Windows con Docker Desktop pueden variar unos MB por la arquitectura y la VM.


## Docker CLI o Docker Desktop

Todos los comandos de la guía funcionan igual con Docker Engine y con Docker Desktop. Cambia dónde corre el daemon y lo que puedes hacer sin teclear.

| | Docker Engine (CLI) | Docker Desktop |
|---|---|---|
| Daemon | Corre en tu Linux, como servicio del sistema | Corre en una VM Linux que gestiona la aplicación |
| Instalación | Paquete `docker-ce` del repositorio de Docker | Instalador gráfico |
| Arranque | `sudo systemctl start docker` | Abre la aplicación y espera a que el motor diga *running* |
| Uso sin `sudo` | Añade tu usuario al grupo `docker` | Ya viene configurado |
| Interfaz gráfica | No incluye | Images, Containers, Volumes, Build |
| Sistemas | Linux (también en servidores) | Linux, macOS y Windows |
| Licencia | Apache 2.0 | Gratis para uso personal, educativo y empresas pequeñas; las grandes necesitan suscripción |

Instalación:

- Docker Engine: <https://docs.docker.com/engine/install/>
- Docker Desktop: <https://docs.docker.com/desktop/>

Docker Desktop crea un contexto propio, normalmente `desktop-linux`. Compruébalo con `docker context ls` y actívalo con `docker context use desktop-linux` si tienes varios.

Esta tabla traduce la guía a la interfaz gráfica. Los nombres de los menús cambian entre versiones; si no encuentras una opción, usa el comando de la columna izquierda.

| Comando de la guía | Dónde está en Docker Desktop |
|---|---|
| `docker build` | Images > Build image |
| `docker run` | Images > Run (icono de play) |
| `docker ps` | Containers > lista |
| `docker logs` | Containers > pestaña Logs |
| `docker inspect` | Containers > pestaña Inspect |
| `docker stats` | Containers > pestaña Stats |
| `docker exec ... sh` | Containers > pestaña Exec |
| `docker images` | Images > columna Size |
| `docker history` | Images > detalle de la imagen > capas |
| `docker rm` y `docker rmi` | Icono de papelera en Containers o Images |

Cada paso del laboratorio incluye una nota "En Docker Desktop" con el equivalente gráfico cuando aporta algo. Los límites de memoria y CPU se explican mejor con la CLI: en la interfaz solo se ajustan los recursos globales de la VM, no los de un contenedor concreto.


## Paso 0. Verificar el entorno

**Objetivo:** confirmar que Docker funciona, que hay espacio y que los límites de recursos están disponibles.

Arranca el motor antes de ejecutar nada. En Linux con Engine: `sudo systemctl start docker`. Con Docker Desktop: abre la aplicación y espera a que indique *Engine running*.

```bash
docker version
docker info --format 'Driver: {{.Driver}} | Cgroup: {{.CgroupVersion}} | Logs: {{.LoggingDriver}}'
docker run --rm hello-world
df -h .
```

**Esperado:**

- `docker version` muestra cliente y servidor (no solo cliente).
- `Driver: overlayfs` (u `overlay2`), `Cgroup: 2`.
- `hello-world` termina con `Hello from Docker!`.
- Al menos 4 GB libres en el directorio.

En Docker Desktop el daemon corre en una VM Linux, así que el driver y el cgroup que ves son los de esa VM. En Windows, `df -h` no existe en PowerShell: usa `Get-PSDrive C` y mira la columna `Free`. El espacio que importa es el de la unidad donde Docker Desktop guarda sus datos, que puedes consultar en Settings > Resources.

**Checkpoint:**

- [ ] El daemon responde.
- [ ] `docker ps` no da error de permisos.
- [ ] Hay espacio suficiente.

Si `docker version` muestra solo el cliente, el daemon no está arrancado. En Linux: `sudo systemctl start docker`. En Docker Desktop: abre la aplicación y espera a que diga *Running*. Si el error menciona `dockerDesktopLinuxEngine`, el motor de Desktop todavía está arrancando o la aplicación está cerrada.

Entra al directorio y mira lo que hay:

```bash
cd clase-01/lab/app
ls -la
```

Deberías ver `app.py`, `requirements.txt`, `Dockerfile.naive`, `Dockerfile`, `Dockerfile.alpine`, `.dockerignore` y `README.md`.


## Paso 1. Construir y ejecutar la imagen ingenua

**Objetivo:** tener una imagen que funciona y sirve de punto de comparación. No la corrijas todavía: los problemas son intencionados.

### 1.1 Lee la aplicación

```bash
cat app.py
cat requirements.txt
```

`app.py` define tres rutas: `/`, `/healthz` y `/productos`. Usa Flask para el desarrollo y gunicorn como servidor. El puerto interno es **8000**.

`.dockerignore` excluye del contexto de build lo que no debe viajar: `.git`, `venv`, `__pycache__`, `*.pyc`, documentación y los propios Dockerfiles.

### 1.2 Construye

```bash
docker build -f Dockerfile.naive -t tienda-api:naive .
```

La primera vez descarga la imagen `python:3.12` completa (~1 GB). Puede tardar varios minutos; es normal.

**Qué hace cada pieza del comando:**

| Parte | Significado |
|---|---|
| `docker build` | Construye una imagen a partir de un Dockerfile |
| `-f Dockerfile.naive` | Usa ese archivo en lugar del `Dockerfile` por defecto |
| `-t tienda-api:naive` | Nombre (`repositorio:etiqueta`) de la imagen resultante |
| `.` | Contexto de build: todo lo no ignorado en este directorio se envía al builder |

En Docker Desktop: Images > Build image. Elige la carpeta `app` como contexto, `Dockerfile.naive` como archivo y `tienda-api:naive` como etiqueta. La imagen resultante es la misma.

### 1.3 Ejecuta

```bash
docker run -d --name tienda-naive -p 18000:8000 tienda-api:naive
```

| Flag | Significado |
|---|---|
| `-d` | En segundo plano (*detached*) |
| `--name tienda-naive` | Nombre fijo para poder referenciarlo |
| `-p 18000:8000` | Puerto del host 18000 → puerto 8000 del contenedor |

En Docker Desktop: Images > `tienda-api:naive` > Run. En el formulario pon `tienda-naive` como nombre y publica el puerto 18000 hacia el 8000 del contenedor. El resto de valores por defecto sirve.

Comprueba que arrancó:

```bash
docker ps --filter name=tienda-naive
docker logs tienda-naive
```

**Esperado:** estado `Up`, y en los logs `Listening at: http://0.0.0.0:8000`.

### 1.4 Prueba los tres endpoints

```bash
curl -s localhost:18000/
curl -s localhost:18000/productos
curl -s localhost:18000/healthz
```

**Esperado:**

```json
{"servicio":"tienda-api","version":"dev"}
{"productos":[{"id":1,"nombre":"Teclado","precio":25.0}, ...]}
{"status":"ok"}
```

Si `curl` devuelve vacío, espera 2 segundos y repite: gunicorn tarda un instante en arrancar.

**Checkpoint:**

- [ ] La imagen se construyó sin errores.
- [ ] El contenedor está `Up`.
- [ ] Los tres endpoints responden.


## Paso 2. Medir la imagen ingenua

**Objetivo:** saber cuánto pesa, de qué está hecha y con qué usuario se ejecuta.

### 2.1 Tamaño

```bash
docker images tienda-api:naive --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'
```

**Esperado:** `1.63GB`.

### 2.2 Capas

```bash
docker history tienda-api:naive --format 'table {{.CreatedBy}}\t{{.Size}}' | head -15
```

Cada línea es una capa de la imagen, en orden inverso (la última instrucción arriba). La columna `SIZE` es lo que esa capa añade.

Observa dos cosas:

1. La capa base de `python:3.12` se lleva la mayor parte del gigabyte.
2. `RUN pip install` añade ~19 MB y `COPY . .` unos kB. La base de `python:3.12` explica casi todo el peso.

### 2.3 Usuario

```bash
docker exec tienda-naive id
docker inspect --format 'User="{{.Config.User}}"' tienda-naive
```

**Esperado:** `uid=0(root)` y `User=""` (vacío significa root).

En Docker Desktop, la pestaña Inspect del contenedor muestra el mismo `Config.User`. La columna Size de Images muestra el tamaño de la imagen.

Si un proceso root escapa del contenedor, el daño posible en el host es mayor. En la imagen final lo corregiremos con `USER`.

### 2.4 (Opcional) Ver las capas visualmente

```bash
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  wagoodman/dive:latest tienda-api:naive
```

Fíjate en *Image efficiency*. Sal con `Ctrl+C`. Si no tienes red o la imagen no está disponible, sáltalo: no es necesario para el resto del lab.

En Docker Desktop el socket del daemon vive dentro de la VM. Si el contenedor de `dive` no conecta, prueba con `-v //var/run/docker.sock:/var/run/docker.sock` o prescinde de esta sección: `docker history` y la vista de capas de Images dan la misma información.

**Preguntas para responder en tus notas:**

1. ¿Qué instrucción aporta más peso?
2. ¿Por qué la app pesa 19 MB y la imagen 1,63 GB?
3. ¿Qué riesgo tiene ejecutar como root?
4. ¿Qué pasaría si no existiera `.dockerignore` y el directorio tuviera `.git` o un `venv`?

**Checkpoint:**

- [ ] Sabes el tamaño exacto.
- [ ] Identificaste la capa más pesada.
- [ ] Confirmaste que corre como root.


## Paso 3. Escribir el Dockerfile multi-stage con test

**Objetivo:** separar el entorno de compilación, el de prueba y el de ejecución. La imagen final solo lleva lo necesario para correr la app.

### 3.1 El concepto

```text
Etapa builder              Etapa test                 Etapa final
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│ python:3.12-slim │       │ python:3.12-slim │       │ python:3.12-slim │
│ + pip + venv     │ ────> │ + /venv + app.py │ ────> │ + /venv + app.py │
│ + caché de pip   │ copia │ + prueba de humo │ copia │ + usuario no root│
└──────────────────┘       └──────────────────┘       └──────────────────┘
      (se descarta)            (no se publica)            (lo que se publica)
```

La imagen final solo contiene lo que copias de `builder` y de `test`. La etapa `test` no se publica, pero su resultado decide si el build continúa.

### 3.2 Requisitos

Escribe tu propio `Dockerfile` (o edita el existente) con:

- [ ] Etapa `builder` basada en `python:3.12-slim` que cree un virtualenv en `/venv`.
- [ ] Dependencias instaladas con `pip install --no-cache-dir -r requirements.txt`.
- [ ] Etapa `test` que copie `/venv` y `app.py`, y compruebe los tres endpoints con `app.test_client()`.
- [ ] Etapa final basada en `python:3.12-slim` (no en la imagen completa).
- [ ] `COPY --from=builder /venv /venv`.
- [ ] `COPY --from=test /app/app.py .` para que el build ejecute la etapa de test.
- [ ] `ENV PATH="/venv/bin:$PATH"` para que `gunicorn` se encuentre.
- [ ] Usuario sin privilegios con UID fijo.
- [ ] `EXPOSE 8000`, `HEALTHCHECK` y `CMD` en forma exec.

Pistas:

- Crear usuario: `RUN useradd --create-home --uid 10001 appuser`.
- Activar usuario: `USER appuser`.
- `HEALTHCHECK` sin `curl` (no está en slim):
  `CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')"`
- `PYTHONDONTWRITEBYTECODE=1` y `PYTHONUNBUFFERED=1` evitan `.pyc` y logs retenidos.
- Prueba de humo sin levantar el servidor:
  `RUN python -c "from app import app; c = app.test_client(); assert c.get('/healthz').status_code == 200"`

### 3.3 Compara con la referencia

Cuando tengas tu versión, compara con `Dockerfile`. No tiene que ser idéntica; revisa sobre todo:

1. Que la etapa final no copie el builder entero.
2. Que el usuario no sea root.
3. Que las dependencias se instalen antes de copiar el código.
4. Que exista una etapa de test y que un fallo en esa etapa detenga el build.

La solución está explicada línea a línea en el **Apéndice C**.

**Checkpoint:**

- [ ] Tu Dockerfile tiene al menos tres etapas: `builder`, `test` y runtime.
- [ ] La etapa final no instala dependencias: las copia.
- [ ] El build ejecuta la prueba de humo y falla si la app está rota.
- [ ] Hay un `USER` distinto de root.


## Paso 4. Construir, comparar y ejecutar con límites

### 4.1 Construye la optimizada

```bash
docker build -t tienda-api:optimized .
docker images tienda-api --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'
```

**Esperado:** `tienda-api:optimized` ~205 MB frente a `tienda-api:naive` 1,63 GB.

El build ejecuta la etapa `test` antes de crear la imagen final. Si la app no pasa la prueba de humo, se detiene y no publica nada. Para ejecutar solo esa etapa:

```bash
docker build --target test -t tienda-api:test .
```

En Docker Desktop puedes construirla desde Images > Build image con `Dockerfile` y la etiqueta `tienda-api:optimized`.

### 4.2 Ejecuta con límites

```bash
docker run -d --name tienda-opt -p 18001:8000 \
  --memory 128m --cpus 0.5 tienda-api:optimized
```

| Flag | Efecto |
|---|---|
| `--memory 128m` | El contenedor no puede usar más de 128 MiB de RAM |
| `--cpus 0.5` | Como máximo, medio núcleo de CPU |

Los límites los impone el kernel mediante cgroups: la aplicación no puede superarlos.

El formulario Run de Docker Desktop no siempre permite fijar memoria y CPU; para estos dos límites usa la CLI. Settings > Resources cambia el techo de la VM completa, que comparten todos los contenedores; no equivale a `--memory` en uno solo.

### 4.3 Verifica funcionamiento, usuario y salud

```bash
sleep 3
curl -s localhost:18001/
docker exec tienda-opt id
docker inspect --format '{{.State.Health.Status}}' tienda-opt
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' tienda-opt
```

**Esperado:**

- La app responde igual que antes.
- `uid=10001(appuser)`.
- El healthcheck puede tardar hasta 60 s en pasar de `starting` a `healthy` (se ejecuta cada 30 s). Puedes esperar con:

```bash
for i in $(seq 1 12); do
  estado=$(docker inspect -f '{{.State.Health.Status}}' tienda-opt)
  echo "$estado"
  [ "$estado" = "healthy" ] && break
  sleep 5
done
```

- Memoria muy por debajo de 128 MiB (la app ociosa usa decenas de MB) y CPU baja.

### 4.4 ¿Qué cambió?

| | Naive | Optimizada |
|---|---|---|
| Base | `python:3.12` | `python:3.12-slim` |
| Etapas | 1 | 3 (`builder`, `test`, runtime) |
| Test en el build | No | Sí |
| Herramientas de build en la imagen final | Sí | No |
| Usuario | root | `appuser` |
| Tamaño | 1,63 GB | 205 MB |
| Healthcheck | No | Sí |

**Checkpoint:**

- [ ] La imagen optimizada pesa ~8 veces menos.
- [ ] Corre como usuario 10001.
- [ ] El healthcheck llega a `healthy`.
- [ ] La app responde.


## Paso 5. Experimento de caché

**Objetivo:** comprobar que el orden de las instrucciones decide qué se reconstruye. Un cambio de código puede costar 2 segundos o 1 minuto de build.

### 5.1 Prepara el experimento

BuildKit (el motor por defecto) indexa el contenido de los archivos, no la fecha. Por eso **tocar** un archivo con `touch` no siempre invalida la capa. Cambia el contenido de verdad y restáuralo al final:

```bash
cp app.py /tmp/app.py.bak
printf '\n# cambio para probar la cache\n' >> app.py
```

### 5.2 Reconstruye la ingenua

```bash
docker build -f Dockerfile.naive -t tienda-api:naive . --progress=plain 2>&1 \
  | grep -E 'CACHED|pip install|COPY \. \.'
```

**Esperado (resumen):**

```text
#6 CACHED
#7 [3/4] COPY . .
#8 [4/4] RUN pip install -r requirements.txt
```

`COPY . .` cambió → se invalida → el `RUN pip install` que viene **después** se vuelve a ejecutar. Aunque las dependencias no hayan cambiado.

### 5.3 Reconstruye la optimizada

```bash
docker build -t tienda-api:optimized . --progress=plain 2>&1 \
  | grep -E 'CACHED|COPY app.py|COPY --from=test|RUN python -m venv|test_client'
```

**Esperado (resumen):**

```text
#8 [builder 4/4] RUN python -m venv /venv && /venv/bin/pip install ...
#8 CACHED
#9 [test 3/5] COPY --from=builder /venv /venv
#9 CACHED
#10 [test 4/5] COPY app.py .
#11 [test 5/5] RUN python -c "from app import app; ..."
#15 [runtime 5/5] COPY --from=test /app/app.py .
```

La instalación de dependencias sigue en caché porque `requirements.txt` no cambió. Se re-ejecutan la prueba y la copia del código: ese es el costo de validar en el build.

En Docker Desktop, la vista de build muestra cada paso con la marca CACHED, sin necesidad de filtrar la salida. En PowerShell no hay `grep`: usa `| Select-String 'CACHED|pip install|COPY'`. Los demás comandos de esta sección están traducidos en el Apéndice D.

### 5.4 Restaura el archivo

```bash
cp /tmp/app.py.bak app.py
tail -3 app.py
```

**Preguntas:**

1. ¿Qué pasos se re-ejecutan en cada imagen?
2. ¿Qué pasaría si cambiaras `requirements.txt` en la optimizada?
3. ¿Por qué `COPY requirements.txt` va antes de `COPY app.py`?
4. ¿Qué hace `--no-cache` y cuándo lo usarías?

**Checkpoint:**

- [ ] Entiendes por qué la ingenua reinstala dependencias.
- [ ] Entiendes por qué la optimizada no.
- [ ] `app.py` quedó restaurado.


## Paso 6. Límites y OOM

**Objetivo:** ver los límites desde dentro del contenedor y provocar un OOM controlado.

### 6.1 Lee los límites en cgroups v2

```bash
docker exec tienda-opt cat /sys/fs/cgroup/memory.max
docker exec tienda-opt cat /sys/fs/cgroup/cpu.max
```

**Esperado:**

```text
134217728
50000 100000
```

Interpretación:

- `memory.max = 134217728` bytes = 128 MiB.
- `cpu.max = "50000 100000"`: 50 ms de CPU por cada 100 ms de periodo = 0,5 CPU.

Si el archivo no existe, estás en cgroups v1 (Docker Desktop antiguo). Usa `/sys/fs/cgroup/memory/memory.limit_in_bytes` y `/sys/fs/cgroup/cpu/cpu.cfs_quota_us`.

En Docker Desktop esta comprobación funciona igual: se ejecuta dentro del contenedor, que es Linux, aunque tu equipo sea macOS o Windows.

### 6.2 Provoca un OOM

```bash
docker run -d --name oom-demo --memory 64m tienda-api:optimized \
  python -c 'a = bytearray(200 * 1024 * 1024)
for i in range(0, len(a), 4096): a[i] = 1'
sleep 3
docker inspect --format 'OOMKilled={{.State.OOMKilled}} exit={{.State.ExitCode}}' oom-demo
```

**Esperado:** `OOMKilled=true exit=137`.

- `137 = 128 + 9`: el proceso recibió `SIGKILL`.
- El bucle toca una página de cada 4 KB. Sin tocarlas, Linux solo reserva memoria virtual y el límite no se alcanza: el contenedor terminaría con éxito y el ejemplo no demostraría nada.
- Si `OOMKilled` aparece `false`, espera un segundo y repite `docker inspect`: el estado puede tardar en reflejarse.

### 6.3 CPU al 50 %

```bash
docker run -d --name cpu-demo --cpus 0.5 tienda-api:optimized \
  python -c 'while True: pass'
sleep 5
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}' cpu-demo
```

**Esperado:** alrededor de `50%`. El proceso pide todo el núcleo, pero el cgroup solo le da medio.

### 6.4 Limpia

```bash
docker rm -f oom-demo cpu-demo
```

**Preguntas:**

1. ¿Qué habría pasado sin `--memory` en un host con 8 GB?
2. ¿Qué diferencia hay entre el límite y el uso real?
3. ¿Por qué el OOM se ve como exit 137 y no como un error de la app?

**Checkpoint:**

- [ ] Viste los límites dentro del contenedor.
- [ ] Provocaste un OOM con exit 137.
- [ ] Confirmaste el límite de CPU al 50 %.


## Paso 7. Reto: bajar de 100 MB

**Objetivo:** reducir la imagen sin romper la aplicación y entender el precio de hacerlo.

### 7.1 Condiciones

- Imagen final **< 100 MB**.
- Los tres endpoints deben seguir respondiendo.
- Usuario no root.
- Nada de secretos en la imagen.

Antes de mirar la solución, intenta al menos una de estas ideas:

1. Cambiar la base a `python:3.12-alpine`.
2. Quitar `pip`, `setuptools` y cachés del virtualenv.
3. Eliminar documentación y tests del contexto.
4. Probar `distroless` (ojo: la versión de Python debe coincidir y no hay shell).

### 7.2 Solución de referencia

```bash
docker build -f Dockerfile.alpine -t tienda-api:alpine .
docker images tienda-api --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'
```

**Esperado:** `tienda-api:alpine` ~79 MB.

En Docker Desktop: Images > Build image con `Dockerfile.alpine` y la etiqueta `tienda-api:alpine`.

Diferencias clave con `Dockerfile`:

- La base es `python:3.12-alpine` (musl en lugar de glibc).
- El build y la ejecución usan **la misma** base: así las wheels coinciden.
- `pip install --no-cache-dir --no-compile` evita caché y `.pyc`.
- Se borran `pip`, `setuptools` y sus scripts del virtualenv (~20 MB).
- `adduser -D -u 10001 appuser` es la variante de Alpine.

### 7.3 Verifica que sigue funcionando

```bash
docker run -d --name tienda-alp -p 18002:8000 tienda-api:alpine
sleep 3
curl -s localhost:18002/
curl -s localhost:18002/productos
curl -s localhost:18002/healthz
docker exec tienda-alp id
```

**Esperado:** mismos JSON, `uid=10001(appuser)`.

### 7.4 Variante distroless

`Dockerfile.distroless` usa una imagen sin shell ni gestor de paquetes y deja el contenedor con el usuario `nonroot` (65532). Como la etapa final no puede ejecutar `RUN`, las dependencias se instalan con `--target` en el builder y se copian enteras.

Si el tiempo aprieta, el docente construye esta variante y la muestra; no es obligatorio que cada alumno la escriba.

```bash
docker build -f Dockerfile.distroless -t tienda-api:distroless .
docker run -d --name tienda-dis -p 18003:8000 tienda-api:distroless
sleep 3
curl -s localhost:18003/
curl -s localhost:18003/productos
curl -s localhost:18003/healthz
docker inspect --format 'User={{.Config.User}}' tienda-dis
docker inspect --format 'Health={{.State.Health.Status}}' tienda-dis
```

**Esperado:** `tienda-api:distroless` ~85 MB, `User=65532`, healthcheck `healthy` y los mismos tres JSON.

Ahora prueba a entrar:

```bash
docker exec tienda-dis sh
docker exec tienda-dis ls /
docker exec tienda-dis id
```

Los tres fallan con `executable file not found in $PATH`: no hay shell, ni `ls`, ni `id`. Para ver el UID se usa Python o la configuración de la imagen:

```bash
docker exec tienda-dis /usr/bin/python3.11 -c 'import os; print(os.getuid())'
```

Detalles del Dockerfile:

- El builder es `python:3.11-slim` porque `python3-debian12` trae Python 3.11. Si usas 3.12, las wheels compiladas no cargan.
- `pip install --target /deps` y `PYTHONPATH=/deps` reemplazan al virtualenv. `rm -rf /deps/bin` quita los scripts de arranque, porque el entrypoint llama a `python -m gunicorn`.
- El `HEALTHCHECK` va en forma exec (`["/usr/bin/python3.11", "-c", "..."]`) porque no existe `/bin/sh`.
- El usuario viene de la etiqueta `:nonroot`, no de un `USER` propio.

En Docker Desktop puedes construirla desde Images > Build image con `Dockerfile.distroless`, pero el `exec` interactivo no sirve: no hay shell.

### 7.5 El trade-off

| Aspecto | `slim` (glibc) | `alpine` (musl) | `distroless` |
|---|---|---|---|
| Tamaño | ~205 MB | ~79 MB | ~85 MB |
| Compatibilidad con wheels | Alta | Media (puede requerir compilar) | Alta si coincide la versión de Python |
| Shell para depurar | Sí | Sí (busybox) | No |
| Superficie de ataque | Media | Menor | Menor |
| Facilidad para el equipo | Alta | Media | Baja |

El tamaño menor tiene costos: si una dependencia nativa no tiene wheel para musl, el build falla o hay que instalar un compilador, y la imagen vuelve a crecer. Distroless tampoco es siempre la más chica: en este caso pesa más que alpine, y a cambio quita shell y paquetes del sistema.

**Checkpoint:**

- [ ] La imagen baja de 100 MB.
- [ ] Los tres endpoints responden.
- [ ] Sabes explicar al menos un trade-off.
- [ ] Si probaste distroless, sabes por qué no hay shell ni `id` y cómo se verifica el usuario sin ellos.


## Paso 8. Entregable y cierre

### 8.1 Informe (5 líneas)

Copia esta plantilla y complétala con tus mediciones reales:

```text
Imagen naive:      ____ MB, usuario: ____
Imagen optimizada: ____ MB, usuario: ____
Imagen reto:       ____ MB, base: ____
Build en frío / en caliente: ____ s / ____ s
Una decisión que tomé y por qué: ______________________________
```

### 8.2 Autoevaluación

Marca lo que cumplas; es la misma evidencia que usa la rúbrica:

- [ ] `docker build` funciona desde cero (sin caché previa).
- [ ] Los tres endpoints responden.
- [ ] `docker exec <contenedor> id` no es root.
- [ ] El `Dockerfile` usa una base con versión fija, no `latest`.
- [ ] Existe `.dockerignore`.
- [ ] El multi-stage no arrastra el builder completo.
- [ ] El informe tiene las mediciones reales.
- [ ] Sabes explicar qué capa se invalida al cambiar `app.py`.

Rúbrica completa: [`../evaluacion/rubrica-clase-01.md`](../evaluacion/rubrica-clase-01.md).

### 8.3 Preguntas de la demo oral

Te pueden preguntar cualquiera de estas; se evalúa la explicación, no la memoria:

1. ¿Dónde vive el kernel del contenedor?
2. ¿Qué diferencia hay entre un namespace y un cgroup?
3. ¿Por qué el contenedor no ve los procesos del host?
4. ¿Qué capa se invalida si cambias `requirements.txt`? ¿Y si cambias `app.py`?
5. ¿Por qué `USER appuser` importa si el contenedor ya está aislado?
6. ¿Qué pasa si quitas `--memory` en producción?
7. ¿Qué trade-off tiene `alpine` frente a `slim`?
8. ¿Por qué no se pasan secretos por `ENV`?

### 8.4 Limpieza

```bash
docker rm -f tienda-naive tienda-opt tienda-alp tienda-dis 2>/dev/null || true
docker rmi tienda-api:naive tienda-api:optimized tienda-api:alpine tienda-api:distroless 2>/dev/null || true
```

No borres imágenes ni contenedores de otros compañeros: elimina solo los que creaste tú.

En Docker Desktop, la papelera de Containers elimina el contenedor y la de Images la imagen. Si la imagen todavía tiene contenedores asociados, borra primero los contenedores.


## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Cannot connect to the Docker daemon` | Daemon parado o sin permisos | `sudo systemctl start docker`; añade tu usuario al grupo `docker` y vuelve a iniciar sesión |
| `error during connect ... dockerDesktopLinuxEngine` | Docker Desktop está cerrado o el motor aún arranca | Abre la aplicación y espera a *Engine running*; revisa `docker context ls` |
| `curl` devuelve HTML o un error de `Invoke-WebRequest` | En PowerShell `curl` es un alias de `Invoke-WebRequest` | Usa `curl.exe` o `Invoke-RestMethod http://localhost:18000/` |
| `docker: command not found` tras instalar Desktop | La terminal se abrió antes de la instalación | Cierra y abre una terminal nueva; comprueba con `docker version` |
| Un archivo montado con `-v` no refleja los cambios | La carpeta no está compartida con la VM | Settings > Resources > File sharing y añade esa ruta |
| `bind: address already in use` | Puerto 18000/18001/18002 ocupado | Usa otro puerto a la izquierda: `-p 18100:8000`. Comprueba con `docker ps` |
| El contenedor aparece `Exited (1)` | Error al arrancar la app | `docker logs <nombre>` para ver el traceback |
| `curl: (7) Failed to connect` | Aún arrancando o puerto mal mapeado | Espera 2 s, revisa `docker ps` y el mapeo `0.0.0.0:18000->8000/tcp` |
| `gunicorn: not found` | No se copió `/venv` o falta el `ENV PATH` | Revisa `COPY --from=builder /venv /venv` y `ENV PATH="/venv/bin:$PATH"` |
| `permission denied` al escribir en `/app` | Corres como `appuser` | Es lo esperado; escribe en `/tmp` o ajusta permisos con `--chown` en el `COPY` |
| Healthcheck en `starting` para siempre | La app no responde en `/healthz` | `docker logs`; verifica que el puerto interno sea 8000 y la ruta exista |
| Healthcheck `unhealthy` | La comprobación falla 3 veces | Ejecuta `docker exec <c> python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/healthz').status)"` |
| `OOMKilled=false` pero exit 137 | Estado aún no actualizado | Espera 1 s y repite `docker inspect`; confirma `docker info --format '{{.CgroupVersion}}'` |
| El build no reutiliza caché | Cambió el contenido, el orden es distinto o usaste `--no-cache` | Revisa el orden `COPY`/`RUN` y ejecuta con `--progress=plain` |
| `no matching distribution found` en Alpine | Dependencia sin wheel para musl | Instala el compilador en el builder o vuelve a `slim` |
| El build falla en la etapa `test` | La app no pasa la prueba de humo | Ejecuta el mismo `python -c` en local o revisa el error con `--progress=plain` |
| `no space left on device` | Imágenes y caché acumuladas | `docker system df`; borra solo tus imágenes y, si es tu equipo, `docker builder prune` |
| El reto no baja de 100 MB | Quedan `pip`, `setuptools` o caché en el venv | Limpia el virtualenv en la etapa builder como en `Dockerfile.alpine` |
| `docker exec <c> sh` falla con `executable file not found` | La imagen es distroless y no tiene shell | Es esperado; usa `docker exec <c> /usr/bin/python3.11 -c '...'` o `docker inspect` |
| En distroless falla `gunicorn` o una wheel | El builder y la imagen final usan versiones distintas de Python | Compila con la misma versión que trae la base (3.11 para `python3-debian12`) |


## Apéndice A. Chuleta de comandos

```bash
# Construir
docker build -f Dockerfile.naive -t tienda-api:naive .
docker build -t tienda-api:optimized .
docker build -f Dockerfile.alpine -t tienda-api:alpine .
docker build -f Dockerfile.distroless -t tienda-api:distroless .
docker build --target test -t tienda-api:test .
docker build --progress=plain -t tienda-api:optimized .

# Ejecutar
docker run -d --name tienda-opt -p 18001:8000 --memory 128m --cpus 0.5 tienda-api:optimized
docker run --rm -it tienda-api:optimized sh   # explorar la imagen

# Inspeccionar
docker ps -a
docker logs --tail 50 tienda-opt
docker images tienda-api
docker history tienda-api:optimized
docker inspect tienda-opt
docker stats --no-stream
docker exec tienda-opt id
docker exec tienda-opt sh -c 'cat /sys/fs/cgroup/memory.max'

# Depurar
docker diff tienda-opt
docker top tienda-opt
docker system df

# Limpiar
docker rm -f tienda-opt
docker rmi tienda-api:optimized
docker builder prune
```

## Apéndice B. Resultados esperados

| Medición | Naive | Optimizada | Alpine (reto) | Distroless |
|---|---|---|---|---|
| Tamaño | 1,63 GB | 205 MB | 78,7 MB | 84,8 MB |
| Base | `python:3.12` | `python:3.12-slim` | `python:3.12-alpine` | `distroless/python3-debian12` |
| Python | 3.12 | 3.12 | 3.12 | 3.11 |
| Usuario | root (0) | 10001 | 10001 | 65532 |
| Shell | Sí | Sí | Sí | No |
| Healthcheck | No | Sí | No (mínimo a propósito) | Sí (forma exec) |
| Multi-stage | No | Sí | Sí | Sí |
| Etapas | 1 | 3 | 2 | 2 |
| Endpoints | 3/3 | 3/3 | 3/3 | 3/3 |
| OOM con 64m | no aplica | exit 137 | no aplica | no aplica |
| CPU con `--cpus 0.5` | no aplica | ~50 % | no aplica | no aplica |

Los tamaños pueden variar unos MB según la versión de la imagen base y la arquitectura.

## Apéndice C. El Dockerfile optimizado, línea a línea

```dockerfile
# Etapa 1: construir dependencias. Se descarta al final.
FROM python:3.12-slim AS builder

WORKDIR /app
# Solo las dependencias: esta capa se reutiliza si requirements.txt no cambia.
COPY requirements.txt .
# Virtualenv aislado; --no-cache-dir evita dejar la caché de pip en la imagen.
RUN python -m venv /venv \
    && /venv/bin/pip install --no-cache-dir -r requirements.txt

# Etapa 2: probar la app antes de publicarla.
FROM python:3.12-slim AS test

# gunicorn está en /venv; estas variables evitan .pyc y buffering de logs.
ENV PATH="/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY --from=builder /venv /venv
COPY app.py .
# Prueba de humo con el cliente de Flask: no necesita levantar el servidor.
RUN python -c "from app import app; c = app.test_client(); \
    assert c.get('/healthz').status_code == 200; \
    assert c.get('/productos').get_json()['productos']; \
    assert c.get('/').get_json()['servicio'] == 'tienda-api'"

# Etapa 3: ejecución. Empieza de cero con la base mínima.
FROM python:3.12-slim AS runtime

# gunicorn está en /venv; estas variables evitan .pyc y buffering de logs.
ENV PATH="/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Usuario sin privilegios con UID fijo (reproducible en cualquier host).
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
# Del builder solo viaja el virtualenv, no el compilador ni la caché.
COPY --from=builder /venv /venv
# Se copia desde test para que Docker ejecute esa etapa y valide la app.
COPY --from=test /app/app.py .

# A partir de aquí, todo corre sin privilegios.
USER appuser
EXPOSE 8000
# Sin curl en slim: se usa la librería estándar.
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')"

# Forma exec: el proceso recibe las señales directamente (SIGTERM limpio).
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
```

### Por qué una etapa de test

- El build se detiene antes de publicar una imagen rota.
- La imagen final no lleva las dependencias ni los archivos del test: solo se copia `app.py` desde esa etapa.
- En CI se puede ejecutar sola con `docker build --target test .`.

### Por qué no `COPY . .`

- Copiar todo invalida la capa de código ante cualquier cambio (incluidos archivos que no se usan).
- Puede arrastrar secretos o basura si el `.dockerignore` está mal.
- La imagen final debe contener solo lo que necesita para ejecutar.

### Por qué no `latest`

`latest` no significa "la más nueva estable": significa "la etiqueta que el mantenedor apunte". Un build de hoy y otro de mañana pueden producir imágenes distintas. Fijar versión hace el build reproducible.

### Por qué el `HEALTHCHECK` no usa `curl`

`python:3.12-slim` no incluye `curl`. Instalarlo solo para el healthcheck añade peso y superficie de ataque. `urllib` ya está en la librería estándar.

## Apéndice D. Windows y PowerShell

Docker Desktop en Windows suele usar el backend WSL2. Los comandos `docker` son idénticos a los de Linux; cambian las utilidades del sistema.

Elige la terminal. Los fragmentos de esta guía usan bash (`cp`, `printf`, `tail`, `grep`, `seq`, `sleep`). Git Bash o una distro WSL2 los ejecutan tal cual. En PowerShell, adapta con esta tabla:

| Bash | PowerShell |
|---|---|
| `df -h .` | `Get-PSDrive C` |
| `cp app.py /tmp/app.py.bak` | `Copy-Item app.py $env:TEMP\app.py.bak` |
| `cp /tmp/app.py.bak app.py` | `Copy-Item $env:TEMP\app.py.bak app.py` |
| `printf '\n# texto\n' >> app.py` | `Add-Content app.py '# texto'` |
| `tail -3 app.py` | `Get-Content app.py -Tail 3` |
| `sleep 3` | `Start-Sleep -Seconds 3` |
| `curl -s localhost:18000/` | `curl.exe -s localhost:18000/` |
| `docker rm -f x 2>/dev/null \|\| true` | `docker rm -f x 2>$null` |
| `for i in $(seq 1 12); do ...; done` | Usa Git Bash o WSL2 |

`curl` en PowerShell es un alias de `Invoke-WebRequest`, que no acepta las mismas opciones. `curl.exe` es el binario real. También puedes usar `Invoke-RestMethod http://localhost:18000/productos`.

Las líneas partidas con `\` no funcionan en PowerShell. Escribe el comando en una sola línea o cambia `\` por un acento grave:

```powershell
docker run -d --name tienda-opt -p 18001:8000 `
  --memory 128m --cpus 0.5 tienda-api:optimized
```

El comando de OOM del Paso 6.2 lleva un salto de línea dentro de las comillas. En PowerShell, escríbelo con un acento grave seguido de `n`:

```powershell
docker run -d --name oom-demo --memory 64m tienda-api:optimized python -c "a = bytearray(200 * 1024 * 1024)`nfor i in range(0, len(a), 4096): a[i] = 1"
```

Rutas y puertos no cambian dentro de los contenedores: siguen siendo `/app`, `/venv` y el puerto 8000. En el host, `cd clase-01\lab\app` y `-p 18000:8000` funcionan igual.

Si `docker run --rm hello-world` funciona en PowerShell, el resto de comandos `docker` de la guía también.
