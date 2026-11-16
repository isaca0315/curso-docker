# Extra de la clase 1: tu primera app con Compose

**Duración:** 40 min · **Participantes:** 6 · **Requisito:** clase 1 terminada

Bloque opcional para cerrar la clase 1 con la imagen optimizada ya construida. Los alumnos pasan de un `docker run` largo a un `compose.yaml` de dos servicios: la API y un proxy Nginx.

No reemplaza la clase 2: la prepara. Aquí solo se ven servicios, puertos, variables, healthchecks, límites y los comandos de operación.

## Materiales

| Archivo | Para qué |
|---|---|
| `slides.md` | Diapositivas Marp (8 min de teoría) |
| `lab/guia-paso-a-paso.md` | Guía del alumno (25 min de lab) |
| `lab/compose.yaml` | Stack base: API y proxy |
| `lab/nginx/nginx.conf` | Proxy a la API |
| `lab/api.env` | Variables del proceso |
| `lab/verificar.sh` | Comprobación automática del extra |

## Agenda (40 min)

| Min | Bloque |
|---|---|
| 00:00-00:08 | De `docker run` a `compose.yaml`: servicios, puertos, variables y límites |
| 00:08-00:33 | Lab guiado: validar, arrancar con `--wait`, operar, bajar |
| 00:33-00:37 | Reto: arrancar la variante Alpine sin editar el YAML |
| 00:37-00:40 | Cierre y checklist |

## Objetivos

Al terminar, cada alumno puede:

1. Leer y validar un `compose.yaml`.
2. Arrancar dos servicios y esperar a que estén sanos.
3. Operar el stack con `ps`, `logs`, `top` y `exec`.
4. Distinguir `.env` de `env_file`.
5. Trasladar los límites de CPU y memoria de la clase 1 al YAML.
6. Bajar el stack con `down`.

## Preparación del aula

```bash
cd clase-01/extra-compose/lab
cp .env.example .env
docker image inspect tienda-api:optimized >/dev/null \
  || docker build -t tienda-api:optimized ../../lab/app
docker pull nginx:1.27-alpine
```

Verificar antes de clase:

```bash
./verificar.sh
```

El script arranca el stack, comprueba endpoints, límites, logs y usuario, y lo deja limpio. Tarda menos de un minuto.

## Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `port is already allocated` | Otro contenedor usa 18020 u 18021 | `docker compose down` o cambiar el puerto en `.env` |
| El healthcheck no pasa | La imagen no responde en `/healthz` | `docker compose logs api` |
| `no such image` | Falta `tienda-api:optimized` | Construirla desde `../../lab/app` |
| El proxy devuelve 502 | La API todavía no está sana | Esperar o revisar `docker compose ps` |
| `env file not found` | Falta `api.env` o no estás en `lab` | Revisar el directorio y `.env.example` |

## Evaluación

Sin nota. Se cierra con el checklist de la última diapositiva y una pregunta oral por persona:

- ¿Qué diferencia hay entre `.env` y `env_file`?
- ¿Por qué `--wait` es mejor que `sleep`?
- ¿Dónde quedaron los límites de CPU y memoria de la clase 1?

## Si sobra tiempo

Pedir que agreguen un tercer servicio con `alpine:3.20` y `command: ["sleep", "infinity"]`, sin publicar puertos. Deben comprobar que aparece en `docker compose ps` y que puede resolver `api` por nombre con `wget`.
