# Lab 2c: operación del stack

**Duración:** 60 min · **Requisitos:** stack de `clase-02/lab` arriba y sano (`docker compose up -d --wait`)

Tres partes independientes: 20, 15 y 20 min. Si solo hay 20 min, haz la parte 1. Al terminar, el stack queda como estaba; las respuestas van al final de la guía de diagnóstico.

## Parte 1. Desarrollo contra producción (20 min)

**Objetivo:** ver el mismo compose con dos configuraciones y una herramienta de apoyo que solo se habilita en desarrollo.

Compara la configuración efectiva:

```bash
cd clase-02/lab
docker compose config | grep -E 'APP_VERSION|published'
docker compose -f compose.yaml config | grep -E 'APP_VERSION|published'
```

**Esperado:** con override, `APP_VERSION: dev` y el puerto 18011 publicado. Sin override, `APP_VERSION: "2.0"` y solo el 18010 del proxy.

Arranca Adminer:

```bash
docker compose --profile tools up -d adminer
docker compose ps
```

Abre <http://localhost:18012> y entra con:

| Campo | Valor |
|---|---|
| Sistema | PostgreSQL |
| Servidor | `db` |
| Usuario | `tienda` |
| Contraseña | la de `secrets/db_password.txt` |
| Base | `tienda` |

Abre la tabla `productos`. Adminer está en `frontend` y `backend`; por eso llega a la base y recibe puerto del host. Es la excepción a la separación de redes y solo se habilita con el profile `tools`.

Prueba `watch` en dos terminales:

```bash
docker compose watch
```

En la segunda:

```bash
touch app/app.py
docker compose logs --tail 5 api
```

**Esperado:** el log muestra la sincronización y Gunicorn recarga. `Ctrl+C` corta `watch`, no el stack.

Cierra Adminer:

```bash
docker compose --profile tools rm -sf adminer
```

**Checkpoint:**

- [ ] Distingues `docker compose up` de `docker compose -f compose.yaml up`.
- [ ] Adminer solo aparece con `--profile tools`.
- [ ] `watch` sincroniza un cambio y el stack sigue arriba al salir.

## Parte 2. Copia de seguridad de Postgres (15 min)

**Objetivo:** distinguir el volumen de una copia de seguridad. El volumen sobrevive a `down`, pero no a `down -v`.

Cuenta las filas y genera el volcado:

```bash
docker compose exec -T db psql -U tienda -d tienda -c 'select count(*) from productos;'
docker compose exec -T db pg_dump -U tienda -d tienda --clean --if-exists > /tmp/tienda.sql
wc -l /tmp/tienda.sql
head -5 /tmp/tienda.sql
```

`--clean --if-exists` hace que la restauración borre y recree la tabla. Sin esas opciones, `psql` avisa de que la tabla ya existe y la carga queda a medias.

Borra los datos y mira el resultado:

```bash
docker compose exec -T db psql -U tienda -d tienda -c 'delete from productos;'
curl -s localhost:18010/productos
```

**Esperado:** `{"productos":[]}`.

Restaura:

```bash
docker compose exec -T db psql -U tienda -d tienda < /tmp/tienda.sql
curl -s localhost:18010/productos
```

**Esperado:** vuelven las tres filas del seed.

**Checkpoint:**

- [ ] El volcado vive en el host, no en el contenedor.
- [ ] Sabes restaurar sin detener el stack.
- [ ] Explicas qué borra `docker compose down -v`.

## Parte 3. Redes a mano (20 min)

**Objetivo:** hacer con `docker network` lo que Compose hace por debajo.

Crea dos redes y un servidor en la interna:

```bash
docker network create extra_frontend
docker network create --internal extra_backend
docker run -d --name extra-web --network extra_backend nginx:1.27-alpine
docker network inspect extra_backend --format '{{range .Containers}}{{.Name}} {{end}}'
```

Comprueba el DNS y el aislamiento:

```bash
docker run --rm --network extra_backend busybox:1.36 wget -qO- http://extra-web | head -3
docker run --rm --network extra_frontend busybox:1.36 wget -qO- http://extra-web || echo "no resuelve"
```

**Esperado:** desde `extra_backend` llega; desde `extra_frontend` falla con `bad address`.

Conecta el mismo contenedor a la segunda red y repite:

```bash
docker network connect extra_frontend extra-web
docker run --rm --network extra_frontend busybox:1.36 wget -qO- http://extra-web | head -3
```

Comprueba que la red interna no sale a Internet:

```bash
docker run --rm --network extra_backend busybox:1.36 wget -qO- -T3 http://example.com || echo "sin salida"
```

Limpia:

```bash
docker rm -f extra-web
docker network rm extra_frontend extra_backend
```

**Checkpoint:**

- [ ] Explicas qué comparten dos contenedores en la misma red.
- [ ] `internal` corta la salida sin cortar el DNS entre contenedores.
- [ ] `docker network connect` añade una red sin recrear el contenedor.

## Preguntas de cierre

Responde cada pregunta en tres líneas dentro de la guía de diagnóstico:

1. ¿Por qué `docker compose -f compose.yaml up` no publica el 18011?
2. ¿Qué diferencia hay entre el volumen de Postgres y `/tmp/tienda.sql`?
3. ¿Qué cambia en `extra-web` después de `docker network connect extra_frontend`?
