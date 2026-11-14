# tienda-api

Aplicación mínima usada como hilo conductor del curso. En la clase 1 solo sirve para aprender a construir imágenes; en la clase 2 se le añadirán PostgreSQL y Redis con Compose.

## Endpoints

| Método | Ruta | Respuesta | Uso |
|---|---|---|---|
| GET | `/` | `{"servicio":"tienda-api","version":"dev"}` | Comprobar que responde |
| GET | `/healthz` | `{"status":"ok"}` | Healthcheck del contenedor |
| GET | `/productos` | Lista de 3 productos | Simular carga útil real |

El puerto interno es `8000`. El servidor de producción es gunicorn; `python app.py` solo se usa para ejecución local.

## Estructura

```text
app/
├── app.py               # aplicación Flask (3 endpoints)
├── requirements.txt     # dependencias fijadas
├── Dockerfile.naive     # imagen ingenua, para comparar (1,63 GB)
├── Dockerfile           # solución multi-stage (205 MB)
├── Dockerfile.alpine    # solución del reto < 100 MB (79 MB)
└── .dockerignore        # excluye docs, git, cachés y venv del contexto
```

## Ejecución local (sin Docker, opcional)

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
gunicorn --bind 127.0.0.1:8000 app:app
# en otra terminal
curl -s localhost:8000/
```

## Variables de entorno

| Variable | Por defecto | Efecto |
|---|---|---|
| `APP_VERSION` | `dev` | Se devuelve en `/` para identificar la versión desplegada |

En la clase 4 se usará para demostrar despliegues versionados sin reconstruir la imagen.

## Los tres Dockerfiles

| Archivo | Base | Usuario | Tamaño medido | Para qué |
|---|---|---|---|---|
| `Dockerfile.naive` | `python:3.12` | root | 1,63 GB | Punto de partida con anti-patrones |
| `Dockerfile` | `python:3.12-slim` | `appuser` (10001) | 205 MB | Referencia multi-stage |
| `Dockerfile.alpine` | `python:3.12-alpine` | `appuser` (10001) | 79 MB | Reto de tamaño |

Los tamaños son los observados con Docker 29 en Linux x86-64; pueden variar ligeramente según la versión de la imagen base.

## Notas de diseño

- Las versiones de `flask` y `gunicorn` están fijadas para que el build sea reproducible.
- El `HEALTHCHECK` usa la librería estándar de Python: `python:3.12-slim` no incluye `curl`.
- La imagen final no lleva compiladores ni caché de pip.
- No hay base de datos: la clase 1 se centra en el ciclo de vida de la imagen.
