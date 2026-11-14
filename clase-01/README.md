# Clase 1: arquitectura, configuración y construcción de imágenes

**Duración:** 4 h · **Participantes:** 6 · **Requisitos:** Docker 24+ y terminal Linux/macOS/WSL2

## Materiales

| Archivo | Para qué |
|---|---|
| `slides.md` | Diapositivas (Marp). Renderizar con `marp slides.md -o slides.pdf` o leerlas como markdown |
| `lab/guia-paso-a-paso.md` | Guía del alumno, paso a paso con resultados esperados |
| `lab/README.md` | Índice del lab y resultados esperados |
| `lab/app/README.md` | Documentación de la aplicación y de los tres Dockerfiles |
| `lab/app/` | Aplicación `tienda-api` + `Dockerfile.naive`, `Dockerfile`, `Dockerfile.alpine`, `.dockerignore` |
| `demos/01-arquitectura.sh` | Namespaces, cgroups, shims y capas en vivo |
| `demos/02-limites.sh` | Límites de CPU/memoria y OOM kill |
| `demos/03-capas-cache.sh` | Tamaño, historial y caché de build |
| `demos/configuracion-daemon.md` | Inspección del daemon y `daemon.json` comentado (opcional en VM) |
| `evaluacion/rubrica-clase-01.md` | Rúbrica y checklist del entregable |
| `recursos/checklist-dockerfile.md` | Chuleta imprimible para el alumno |

## Cómo usar este material

**Instructor**

1. Lee este README y revisa la agenda.
2. Renderiza las diapositivas si las quieres en PDF: `marp slides.md -o slides.pdf` (o proyecta el Markdown).
3. Ejecuta los demos una vez antes de clase para confirmar que funcionan en el aula.
4. Pre-descarga las imágenes de la sección "Preparación del aula".

**Alumno**

1. Abre `lab/guia-paso-a-paso.md` y síguela en orden.
2. Intenta escribir el `Dockerfile` antes de mirar la solución.
3. Usa `recursos/checklist-dockerfile.md` como repaso y `evaluacion/rubrica-clase-01.md` para saber cómo se te evalúa.

## Agenda (240 min)

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:20 | Bienvenida, diagnóstico y verificación de entornos | `docker info`, `docker run hello-world` |
| 00:20-01:00 | Arquitectura y características | `slides.md` + `demos/01-arquitectura.sh` |
| 01:00-01:45 | Configuración de Docker | `slides.md` + `demos/configuracion-daemon.md` |
| 01:45-01:55 | Pausa | sin material |
| 01:55-02:15 | Construcción de imágenes (Dockerfile, caché, multi-stage) | `slides.md` |
| 02:15-03:15 | Lab 1 | `lab/guia-paso-a-paso.md` pasos 1-6 |
| 03:15-03:25 | Pausa | sin material |
| 03:25-04:00 | Reto < 100 MB, puesta en común y cierre | `lab/guia-paso-a-paso.md` pasos 7-8 + `Dockerfile.alpine` |

## Conceptos clave

- **Contenedor ≠ VM.** El kernel es compartido; lo que aísla son namespaces y lo que limita son cgroups.
- **Arquitectura real:** `docker` (CLI) → `dockerd` → `containerd` → `runc` → proceso. El shim mantiene vivo el contenedor si el daemon se reinicia.
- **Capas:** cada instrucción del Dockerfile crea una capa; el contenedor añade una capa de escritura efímera. `docker diff` lo demuestra.
- **Orden del Dockerfile:** decide qué capas se reutilizan. Dependencias antes que código.
- **Multi-stage:** compilar en una etapa, ejecutar en otra. La imagen final solo contiene lo que copias.
- **Usuario no root:** toda imagen de producción necesita un `USER`.
- **Configuración:** el daemon se configura con `daemon.json` o con flags de systemd.

## Guion de demos

1. **Arquitectura** (`demos/01-arquitectura.sh`): mostrar PID del host, shims, namespaces, cgroup y capa de escritura. Preguntar: *¿dónde está el kernel del contenedor?*
2. **Límites** (`demos/02-limites.sh`): `--cpus 0.5` se refleja en `cpu.max`; `--memory 64m` termina en OOM (exit 137). Preguntar: *¿qué pasa si no pongo límites?*
3. **Capas y caché** (`demos/03-capas-cache.sh`): comparar 1.63 GB vs 205 MB vs 79 MB; cambiar el contenido de `app.py` y ver qué pasos se re-ejecutan.
4. **Daemon** (`demos/configuracion-daemon.md`): inspección en vivo; rotación de logs con flags del CLI. El cambio de `daemon.json` solo se aplica en VM de práctica.

## Errores comunes y cómo resolverlos

| Síntoma | Causa | Solución |
|---|---|---|
| `bind: address already in use` | Puerto ocupado | `-p 18000:8000` o `docker rm -f` del contenedor viejo |
| La imagen pesa casi lo mismo que la base | El multi-stage no copia solo lo necesario | Revisar `COPY --from`; no copiar el builder entero |
| `permission denied` al escribir | `USER appuser` | Escribir en `/tmp` o dar permisos explícitos; es lo esperado |
| El build no usa caché | Se copió código antes de instalar dependencias | Reordenar `COPY requirements.txt` + `RUN pip install` antes de `COPY .` |
| `exec format error` o fallo en alpine | Binarios compilados para otra libc | Compilar en la misma base que se ejecuta (musl vs glibc) |
| Healthcheck en `starting` para siempre | La app no responde en `/healthz` | `docker logs`; verificar puerto y ruta |
| `docker build` envía un contexto enorme | Falta `.dockerignore` | Añadir `.git`, `venv`, `node_modules`, etc. |

## Evaluación

- Entregable: `Dockerfile` multi-stage funcionando + informe de 5 líneas con tamaños y tiempos medidos.
- Rúbrica: `evaluacion/rubrica-clase-01.md` (40 % del curso repartido entre las 4 clases).
- Cierre oral (5 min): cada alumno responde una pregunta distinta (namespaces, cgroups, capas, multi-stage, caché, OOM).

## Preparación del aula

```bash
# Pre-descargar para no depender del wifi del aula
docker pull python:3.12
docker pull python:3.12-slim
docker pull python:3.12-alpine
docker pull alpine:3.20

# Verificar que el entorno permite límites y nombres de contenedor
docker run --rm --memory 64m alpine sh -c 'echo ok'
```

Si el aula es remota, cada alumno trabaja en su equipo. Si es un host compartido, asignar un rango de puertos por alumno (`18000 + n`) y un prefijo de nombre de contenedor.
