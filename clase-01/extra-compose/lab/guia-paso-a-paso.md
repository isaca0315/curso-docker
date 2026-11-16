# Guía paso a paso: tu primera app con Compose

| Dato | Valor |
|---|---|
| Duración | 25 min de lab (extra de 40 min de la clase 1) |
| Directorio de trabajo | `clase-01/extra-compose/lab` |
| Requisito | Clase 1 terminada: `tienda-api:optimized` construida |
| Entregable | Stack `api + proxy` sano, con límites y logs, arrancado con un solo comando |

## Qué vas a aprender

1. Pasar de un `docker run` con muchos flags a un `compose.yaml`.
2. Arrancar dos servicios y esperar a que estén sanos con `up --wait`.
3. Operar el stack con `ps`, `logs`, `top` y `exec`.
4. Distinguir `.env` (interpolación) de `env_file` (variables del contenedor).
5. Aplicar los límites de CPU y memoria de la clase 1 desde el YAML.
6. Bajar el stack completo con `down`.

## Mapa de pasos

| Paso | Qué haces | Tiempo |
|---|---|---|
| 0 | Verificar la imagen y crear `.env` | 2 min |
| 1 | Leer el YAML y validarlo | 4 min |
| 2 | Arrancar con `--wait` | 4 min |
| 3 | Operar los servicios | 4 min |
| 4 | Variables y puertos | 3 min |
| 5 | Límites y logs | 3 min |
| 6 | Bajar y volver a arrancar | 3 min |
| 7 | Reto corto y limpieza | 2 min |

## Convenciones

- Todos los comandos se ejecutan desde `clase-01/extra-compose/lab`.
- La API publica 18020 y el proxy 18021.
- El proyecto se llama `tienda-extra`.
- En PowerShell, cambia `curl` por `curl.exe` y `cp` por `Copy-Item`.

## Paso 0. Verificar el entorno

```bash
docker compose version
docker image inspect tienda-api:optimized >/dev/null && echo "imagen ok"
cp .env.example .env
```

Si falta la imagen:

```bash
docker build -t tienda-api:optimized ../../lab/app
```

**Checkpoint:** `docker compose version` responde v2.24 o superior.

## Paso 1. Leer el YAML y validarlo

Abre `compose.yaml`. Cada bloque bajo `services:` es un contenedor.

```bash
docker compose config
docker compose config --services
```

**Esperado:** el YAML expandido con los valores de `.env`, y la lista `api` y `proxy`.

Fíjate en estas claves:

| Clave | Qué hace |
|---|---|
| `image` | Imagen que se usa |
| `ports` | Puerto del host que llega al contenedor |
| `env_file` | Variables que recibe el proceso |
| `healthcheck` | Comando que decide si el servicio está sano |
| `depends_on` + `condition` | Espera a que el otro servicio esté sano |
| `deploy.resources.limits` | Techo de CPU y memoria |

`docker compose config` resuelve `${...}` con `.env`. Si el archivo tiene un error de sintaxis, este comando falla antes de arrancar nada.

## Paso 2. Arrancar con `--wait`

```bash
docker compose up -d --wait
docker compose ps
```

**Esperado:**

```text
SERVICE   STATUS                    PORTS
api       Up ... (healthy)          0.0.0.0:18020->8000/tcp
proxy     Up ... (healthy)          0.0.0.0:18021->80/tcp
```

Prueba los dos caminos:

```bash
curl -s localhost:18020/
curl -s localhost:18021/productos
```

**Esperado:** la API responde directo y el proxy responde lo mismo a través de `http://api:8000`.

`--wait` no vuelve hasta que los healthchecks pasan. Si uno falla, el comando sale con error. Sin `--wait`, `up -d` vuelve en cuanto crea los contenedores, aunque la app todavía no esté lista.

## Paso 3. Operar los servicios

```bash
docker compose logs --tail=5 api
docker compose top
docker compose exec api id
docker compose ps --format 'table {{.Service}}\t{{.Status}}'
```

**Esperado:** logs de gunicorn, el proceso de la API, y `uid=10001(appuser)`.

- `logs` muestra la salida de un servicio.
- `top` muestra los procesos del servicio.
- `exec` entra en un contenedor que ya está corriendo.
- `run` crea un contenedor temporal; no lo uses para mirar el que ya corre.

## Paso 4. Variables y puertos

```bash
cat .env
cat api.env
docker compose config | grep -A2 'environment:'
```

- `.env` alimenta la interpolación `${...}` del compose.
- `api.env` entrega `APP_VERSION=extra` al proceso dentro del contenedor.

Prueba otro puerto sin tocar el YAML:

```bash
API_PORT=18030 docker compose config | grep -A3 'published:'
```

**Esperado:** `published: "18030"`. Sin esa variable se usa el valor de `.env`.

## Paso 5. Límites y logs

```bash
api_id=$(docker compose ps -q api)
docker inspect -f 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}}' "$api_id"
docker inspect -f '{{index .HostConfig.LogConfig.Config "max-size"}}' "$api_id"
docker stats --no-stream api
```

**Esperado:**

```text
Memory=134217728 NanoCpus=500000000
10m
```

- `128M` son 134217728 bytes.
- `cpus: "0.50"` son 500000000 nanocpus.
- `max-size: "10m"` y `max-file: "3"` evitan que los logs llenen el disco.
- `deploy.resources.limits` funciona con `docker compose up` normal, no hace falta Swarm.

## Paso 6. Bajar y volver a arrancar

```bash
docker compose down
docker compose ps -a
docker compose up -d --wait
docker compose ps
```

**Esperado:** después de `down` no queda nada del proyecto; después de `up` vuelve a estar sano.

- `down` borra contenedores y la red del proyecto.
- `down -v` borra además los volúmenes. Aquí no hay, pero en la clase 2 sí importa.
- `restart: unless-stopped` hace que Docker reinicie un servicio si el proceso muere.

## Paso 7. Reto corto y limpieza

Arranca la variante Alpine sin editar el YAML:

```bash
docker compose down
TAG=alpine docker compose config | grep 'tienda-api'
TAG=alpine docker compose up -d --wait
curl -s localhost:18021/
docker compose down
```

**Esperado:** `image: tienda-api:alpine` y la misma respuesta de la API. La bajada previa evita que Nginx conserve la IP vieja de la API.

Limpieza final:

```bash
docker compose down --remove-orphans
docker network ls | grep tienda-extra || echo "red limpia"
```

**Checkpoint final:**

- [ ] `docker compose config --quiet` pasa.
- [ ] `docker compose up -d --wait` deja los dos servicios sanos.
- [ ] La API y el proxy responden.
- [ ] `docker exec` confirma el usuario 10001.
- [ ] Los límites y la rotación de logs se ven en `docker inspect`.

## Apéndice. Errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `port is already allocated` | Otro contenedor usa 18020 u 18021 | `docker compose down` o cambiar el puerto en `.env` |
| El healthcheck nunca pasa | La imagen no responde en `/healthz` | `docker compose logs api` |
| `no such image` | Falta `tienda-api:optimized` | Construirla desde `../../lab/app` |
| `env file ... not found` | Falta `api.env` o `.env` | Revisar que estés en `lab` y copiar `.env.example` |
| El proxy devuelve 502 | La API no está sana | `docker compose ps`; esperar el healthcheck |
| `docker compose` no existe | Solo está el binario `docker-compose` viejo | Instalar el plugin v2 |
