---
marp: true
theme: default
paginate: true
header: "Docker Avanzado · Clase 1"
---

# Docker Avanzado

## Clase 1: arquitectura, configuración y construcción de imágenes

4 horas · 6 participantes · Lab con `tienda-api`

---

# Contenido

1. Qué hay debajo de `docker run`
2. Cómo configurar Docker con criterio
3. Cómo construir imágenes propias pequeñas y seguras
4. Lab: de una imagen de 1,6 GB a una de 79 MB

**Hilo del curso:** la misma app se construye hoy, se compone en la clase 2, se orquesta en la 3 y se asegura/automatiza en la 4.

---

# Contenedor ≠ máquina virtual

| | Máquina virtual | Contenedor |
|---|---|---|
| Kernel | Propio, emulado | Compartido con el host |
| Arranque | Segundos/minutos | Milisegundos |
| Aislamiento | Hardware virtual | Namespaces + cgroups |
| Densidad | Decenas | Cientos |
| Imagen | Disco completo | Capas de sistema de archivos |

Un contenedor **es un proceso** del host con una vista distinta del sistema.

---

# Arquitectura de Docker

```text
docker CLI ──HTTP/socket──> dockerd ──gRPC──> containerd ──> runc ──> proceso
                               │                  │
                          imágenes, redes,     shim por contenedor
                          volúmenes, logs      (mantiene vivo el contenedor)
```

- **CLI**: habla con el daemon por `/var/run/docker.sock` o por TCP/TLS.
- **dockerd**: API, orquestación local, build (BuildKit), redes, volúmenes.
- **containerd**: ciclo de vida de contenedores e imágenes.
- **runc**: crea namespaces y cgroups y ejecuta el proceso.
- **shim**: sobrevive a reinicios del daemon (`live-restore`).

---

# Ciclo de vida de un contenedor

```text
pull ──> unpack (capas) ──> create (config + capa escribible)
     ──> start (runc: namespaces + cgroups + exec)
     ──> running ──> stop ──> rm
```

- `docker create` no ejecuta nada.
- La capa escribible es efímera: si borras el contenedor, se pierde.
- Los volúmenes existen fuera del ciclo de vida del contenedor.

---

# Namespaces: lo que ves

| Namespace | Aísla |
|---|---|
| `pid` | Procesos (el contenedor ve su PID 1) |
| `net` | Interfaces, rutas, puertos, DNS |
| `mnt` | Puntos de montaje y sistema de archivos |
| `uts` | Hostname |
| `ipc` | Memoria compartida y semáforos |
| `user` | UIDs/GIDs (base de rootless) |
| `cgroup` | Vista del árbol de cgroups |
| `time` | Reloj (opcional) |

Demo: `ls -l /proc/<pid>/ns/` del proceso del contenedor en el host.

---

# cgroups: lo que puedes usar

- Limitan y contabilizan CPU, memoria, I/O, PIDs.
- `--cpus 0.5` → `cpu.max` = `50000 100000`.
- `--memory 128m` → `memory.max` = `134217728`.
- Si el proceso excede memoria: **OOM kill**, exit code **137**.
- Sin límites, un contenedor puede consumir todo el host.

Demo: `demos/02-limites.sh`

---

# Límites de CPU y RAM

| Quiero | Flag | cgroup v2 |
|---|---|---|
| Techo de memoria | `--memory 128m` | `memory.max` |
| Reserva de memoria | `--memory-reservation 64m` | `memory.low` |
| Techo de CPU | `--cpus 0.5` | `cpu.max` |
| Peso entre contenedores | `--cpu-shares 512` | `cpu.weight` |
| Núcleos concretos | `--cpuset-cpus 0` | `cpuset.cpus.effective` |
| Máximo de procesos | `--pids-limit 100` | `pids.max` |

- `--memory` es un techo duro: al pasarlo, OOM kill (137).
- `--memory-reservation` es blando: solo actúa bajo presión de memoria.
- `--cpu-shares` no pone techo: reparte CPU cuando varios contenedores compiten.
- Solo `--cpus` y `--cpuset-cpus` limitan CPU de verdad.

---

# Capas: la imagen es inmutable

```text
imagen:   [base] [deps] [código]
           ↓
contenedor: [base] [deps] [código] [capa escribible]
```

- Cada instrucción del Dockerfile genera una capa (casi siempre).
- Las capas se comparten entre imágenes: no se duplican en disco.
- `docker history` muestra el tamaño de cada capa.
- `docker diff` muestra lo que cambió en la capa escribible.
- Borrar un archivo en otra capa **no** reduce el tamaño de la imagen.

---

# Estándares OCI

- **OCI Image Spec**: formato de imagen (manifest, config, layers).
- **OCI Runtime Spec**: cómo se ejecuta (runc, crun, youki).
- Docker produce y consume imágenes OCI; Kubernetes también.
- `docker save` / `docker load` para mover imágenes sin registry.
- BuildKit es el motor de build moderno: caché, secretos de build, multiplataforma.

---

# Configurar Docker: tres niveles

1. **CLI / runtime**: `docker run --memory`, `--cpus`, `--log-opt`.
2. **Daemon**: `/etc/docker/daemon.json` + reinicio del servicio.
3. **Cliente**: `~/.docker/config.json`, contextos (`docker context`).

Lo que debe cumplirse siempre va en el daemon; lo puntual, en el comando.

---

# `daemon.json` típico de producción

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-address-pools": [
    { "base": "172.30.0.0/16", "size": 24 }
  ],
  "no-new-privileges": true
}
```

- Validar: `dockerd --validate --config-file /etc/docker/daemon.json`
- Aplicar: `systemctl restart docker` (con `live-restore`, los contenedores sobreviven).
- En rootless: `~/.config/docker/daemon.json`.

---

# Storage drivers y logs

**Storage driver**
- `overlay2` es el estándar en Linux (requiere kernel moderno).
- `btrfs`, `zfs`, `vfs` (lento, solo casos especiales).
- `docker info` muestra el driver activo.
- El driver afecta rendimiento y uso de disco, no la portabilidad de la imagen.

**Logs**
- Por defecto `json-file` sin límite → **llena el disco**.
- Rotación: `max-size` + `max-file`, por contenedor o en el daemon.
- Alternativas: `local`, `journald`, driver centralizado (fluentd, Loki).

Demo: `demos/configuracion-daemon.md`

---

# Rootless y contextos remotos

**Rootless** (contenedor sin root en el host)
- `dockerd-rootless-setuptool.sh install`
- Usa `user` namespaces; sin privilegios sobre el host.
- Limitaciones: algunas redes y `--privileged` no funcionan igual.

**Contextos**
- `docker context create prod --docker "host=ssh://user@host"`
- `docker context use prod`
- Útil para operar un host remoto sin copiar el socket.

---

# Anatomía de un Dockerfile

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN python -m venv /venv && /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim
ENV PATH="/venv/bin:$PATH"
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
COPY --from=builder /venv /venv
COPY app.py .
USER appuser
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
```

El Dockerfile fija la base, el orden de las capas, el usuario y el tamaño final.

---

# Caché: el orden importa

```dockerfile
# mal: cualquier cambio en el código invalida la instalación
COPY . .
RUN pip install -r requirements.txt

# bien: las dependencias solo se reinstalan si cambian
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
```

- BuildKit reutiliza capas si la instrucción y el contenido no cambian.
- Cambiar una capa invalida **todas las siguientes**.
- `--no-cache` para forzar; `--progress=plain` para ver qué se reutiliza.

Demo: `demos/03-capas-cache.sh`

---

# Multi-stage: compilar, probar y publicar

```dockerfile
FROM python:3.12-slim AS builder     # herramientas y dependencias
...
FROM python:3.12-slim AS test        # prueba de humo; si falla, no hay imagen
COPY --from=builder /venv /venv
RUN python -c "from app import app; ..."
...
FROM python:3.12-slim                # solo lo necesario para ejecutar
COPY --from=builder /venv /venv
COPY --from=test /app/app.py .
```

- La imagen final no incluye compiladores, cachés ni credenciales.
- La etapa `test` no se publica, pero un fallo detiene el build.
- Reduce tamaño y superficie de ataque.
- Patrón habitual: `builder` + `test` + runtime mínimo (slim, alpine, distroless).

---

# Elegir imagen base

| Base | Tamaño aprox. | Cuándo |
|---|---|---|
| `python:3.12` | ~1 GB | Nunca en producción |
| `python:3.12-slim` | ~130 MB | Estándar, glibc, compatible |
| `python:3.12-alpine` | ~50 MB | Tamaño mínimo, ojo con musl |
| `distroless/python3` | ~80 MB | Sin shell ni paquetes, más difícil de depurar |

La base más pequeña reduce el tamaño, pero puede complicar la compatibilidad, los CVEs y la depuración.

---

# Contexto y `.dockerignore`

- `docker build .` envía el directorio al daemon (BuildKit).
- Sin `.dockerignore` viajan `.git`, `venv`, `node_modules`, binarios, secretos.
- Más contexto = build más lento y riesgo de filtrar datos.
- El `.dockerignore` de la imagen no se copia si lo excluyes.

---

# Seguridad básica en el Dockerfile

- `USER` no root (UID fijo, sin shell).
- Versiones fijadas (`python:3.12-slim`, `flask==3.0.3`), no `latest`.
- Sin secretos en `ENV`, `ARG` ni capas: quedan en el historial.
- `--no-cache-dir` al instalar dependencias.
- `HEALTHCHECK` para que el runtime sepa si está sano.
- En la clase 4: `cap-drop`, `read-only`, seccomp, escaneo y firma.

---

# Anti-patrones frecuentes

- `FROM ubuntu` + instalar Python a mano.
- `COPY . .` antes de instalar dependencias.
- `RUN apt-get update` sin `&& rm -rf /var/lib/apt/lists/*`.
- Ejecutar como root "porque funciona".
- Un proceso por contenedor… o cinco sin supervisión.
- `latest` en producción.
- Secretos en la imagen.
- Imagen de 1,6 GB para una API de 3 endpoints.

---

# Lab 1 (60 min)

Objetivo: construir `tienda-api` con una imagen multi-stage, comparar y medir.

1. Build ingenuo y ejecución
2. Tamaño, capas y usuario
3. Escribir el `Dockerfile` multi-stage
4. Comparar y ejecutar como no root
5. Experimento de caché
6. Límites de CPU/memoria y OOM

Guía: `lab/guia-paso-a-paso.md`

---

# Reto (20 min)

## Bajar de 100 MB sin romper la app

- Pista: la base y lo que copias importan más que el código.
- Referencia: `Dockerfile.alpine` (79 MB) y `Dockerfile.distroless` (85 MB, sin shell).
- Preguntas para la puesta en común:
  - ¿Qué trade-off introduce musl?
  - ¿Qué ganas y qué pierdes sin shell?
  - ¿Qué dejarías fuera en un entorno real?
  - ¿Cómo verificarías que la app sigue sana?

---

# Cierre

Checklist de la clase:

- [ ] Sé qué proceso ejecuta mi contenedor y dónde vive en el host
- [ ] Entiendo namespaces y cgroups
- [ ] Sé configurar el daemon sin romper el host
- [ ] Escribo un Dockerfile multi-stage con usuario no root
- [ ] Sé medir tamaño, capas y tiempos de build
- [ ] Entiendo por qué el orden del Dockerfile afecta la caché

**Próxima clase:** Compose y networking avanzado.

<!--
Notas para el instructor:
- No avanzar a la diapositiva de configuración sin haber mostrado la demo de arquitectura.
- Si el grupo es rápido, pedir que expliquen el OOM con sus palabras antes del lab.
- Guardar 5 minutos al final para el entregable y la pregunta oral.
-->
