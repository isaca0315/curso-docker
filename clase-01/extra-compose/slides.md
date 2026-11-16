---
marp: true
theme: default
paginate: true
header: "Docker Avanzado · Clase 1 · Extra Compose"
---

# Tu primera app con Compose

## Extra de la clase 1 · 40 minutos

La imagen optimizada ya está construida. Ahora se arranca con un archivo.

---

# El problema

Lo que hicimos en la clase 1:

```bash
docker run -d --name tienda -p 18001:8000 \
  --memory 128m --cpus 0.5 \
  --restart unless-stopped tienda-api:optimized
```

Y todavía falta el proxy. Cada compañero escribe el comando distinto.

Compose guarda esa configuración en un archivo versionable.

---

# Qué es Compose

- Un archivo YAML describe servicios, redes, volúmenes y límites.
- Un comando crea todo el conjunto.
- El proyecto agrupa los contenedores con un nombre.
- Compose v2 es el plugin `docker compose`; `docker-compose` es la versión vieja.

```bash
docker compose up -d --wait
```

---

# Anatomía del compose

```yaml
services:
  api:
    image: tienda-api:optimized
    ports:
      - "18020:8000"
    env_file: ./api.env
    healthcheck:
      test: ["CMD", "python", "-c", "..."]
    depends_on:
      - proxy
```

Cada servicio es un contenedor. Las claves se leen de arriba abajo.

---

# El compose del lab

```yaml
services:
  api:
    image: tienda-api:${TAG:-optimized}
    ports: ["${API_PORT:-18020}:8000"]
    healthcheck: ...
  proxy:
    image: nginx:1.27-alpine
    ports: ["${PROXY_PORT:-18021}:80"]
    depends_on:
      api:
        condition: service_healthy
```

`${VAR:-default}` toma el valor de `.env` o usa el default.

---

# Los comandos que importan

```bash
docker compose config        # resuelve y valida
docker compose up -d --wait  # arranca y espera healthchecks
docker compose ps            # estado
docker compose logs -f api   # salida
docker compose exec api id   # entra en un contenedor vivo
docker compose down          # borra contenedores y red
```

`--wait` devuelve error si un servicio no llega a sano.

---

# `.env` no es `env_file`

| Archivo | Para qué |
|---|---|
| `.env` | Variables que usa el propio YAML en `${...}` |
| `api.env` | Variables que recibe el proceso dentro del contenedor |

```yaml
env_file: ./api.env
```

Si confundes los dos, la app arranca sin la variable que esperaba.

---

# Límites y logs, ahora en YAML

```yaml
deploy:
  resources:
    limits:
      cpus: "0.50"
      memory: 128M
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Es lo mismo que `--cpus`, `--memory` y `--log-opt`, pero queda escrito.

---

# Errores típicos

| Síntoma | Causa |
|---|---|
| `port is already allocated` | Otro contenedor usa el puerto |
| El healthcheck no pasa | La imagen no responde en `/healthz` |
| `no such image` | Falta construir la imagen |
| El proxy devuelve 502 | La API todavía no está sana |
| `env file not found` | Falta `api.env` o no estás en `lab` |

---

# Lab: 25 minutos

1. Validar el compose con `config`
2. Arrancar con `up -d --wait`
3. Probar API y proxy
4. Operar con `ps`, `logs`, `exec`
5. Ver límites y rotación de logs
6. Bajar con `down`
7. Reto: arrancar la variante Alpine sin editar el YAML

Guía: `clase-01/extra-compose/lab/guia-paso-a-paso.md`

---

# Cierre

- [ ] Sé leer un `compose.yaml`
- [ ] Distingo `.env` de `env_file`
- [ ] Arranco y espero con `--wait`
- [ ] Compruebo límites y logs con `docker inspect`
- [ ] Bajo el stack con `down`

**Siguiente paso:** en la clase 2, este mismo stack suma base de datos, Redis, redes separadas y secretos.
