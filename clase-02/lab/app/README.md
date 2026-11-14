# tienda-api (clase 2)

La misma API de la clase 1, ahora con estado. Lee productos de Postgres y cuenta visitas en Redis. Sigue siendo pequeña a propósito: lo importante es el stack de Compose, no el código.

## Endpoints

| Método | Ruta | Respuesta | Uso |
|---|---|---|---|
| GET | `/` | Servicio, versión y estado de `db` y `redis` | Comprobar dependencias |
| GET | `/healthz` | `{"status":"ok"}` | Liveness: la API responde |
| GET | `/readyz` | `{"status":"ready"}` o 503 | Readiness: la API y sus dependencias |
| GET | `/productos` | Lista desde Postgres | Leer datos |
| POST | `/productos` | Crea un producto | Escribir datos |
| GET | `/visitas` | Contador de Redis | Comprobar caché |

`/healthz` no consulta la base a propósito: sirve para saber si el proceso vive. `/readyz` sí consulta Postgres y Redis, y es el que debe usar un balanceador o Kubernetes.

## Variables de entorno

| Variable | Por defecto | Efecto |
|---|---|---|
| `APP_VERSION` | `dev` | Se devuelve en `/` |
| `DATABASE_HOST` | `db` | Host de Postgres |
| `DATABASE_PORT` | `5432` | Puerto de Postgres |
| `DATABASE_NAME` | `tienda` | Base de datos |
| `DATABASE_USER` | `tienda` | Usuario |
| `DB_PASSWORD` | vacío | Contraseña directa; útil en Kubernetes |
| `DB_PASSWORD_FILE` | vacío | Archivo con la contraseña; lo usa Compose |
| `REDIS_URL` | `redis://redis:6379/0` | Conexión a Redis |

La contraseña se lee de `DB_PASSWORD` o de `DB_PASSWORD_FILE`, en ese orden. Compose usa el archivo montado en `/run/secrets/db_password`; Kubernetes usa una variable desde un `Secret`.

## Arranque del stack

Desde `clase-02/lab`:

```bash
cp secrets/db_password.txt.example secrets/db_password.txt
docker compose up -d --build
curl -s localhost:18010/readyz
```

La API crea la tabla `productos` y la siembra con tres filas al arrancar. Reintenta durante 60 segundos si Postgres aún no acepta conexiones.

## Estructura

```text
app/
├── app.py            # Flask + psycopg2 + redis
├── requirements.txt  # versiones fijadas
├── Dockerfile        # multi-stage, usuario 10001
└── .dockerignore
```

## Notas de diseño

- El healthcheck de la imagen usa `/healthz` y la librería estándar, porque `python:3.12-slim` no trae `curl`.
- gunicorn arranca dos workers en producción y uno con `--reload` en desarrollo.
- La tabla se crea con `IF NOT EXISTS`; dos workers pueden ejecutar el init a la vez sin duplicar filas (el `INSERT` de ejemplo usa ids fijos y `count(*)`).
- El código no guarda la contraseña en logs ni en la respuesta de `/`.
- `Dockerfile.hardened` es la variante de la clase 4: usuario sin shell, sin pip en runtime y compatible con sistema de archivos de solo lectura. La imagen de la clase 2 sigue usando `Dockerfile`.
