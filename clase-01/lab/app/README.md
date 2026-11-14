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
├── Dockerfile           # solución multi-stage con test (3 etapas, 205 MB)
├── Dockerfile.alpine    # solución del reto < 100 MB (79 MB)
├── Dockerfile.distroless # variante sin shell ni gestor de paquetes (85 MB)
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

## Los cuatro Dockerfiles

| Archivo | Base | Usuario | Tamaño medido | Para qué |
|---|---|---|---|---|
| `Dockerfile.naive` | `python:3.12` | root | 1,63 GB | Punto de partida con anti-patrones |
| `Dockerfile` | `python:3.12-slim` | `appuser` (10001) | 205 MB | Referencia multi-stage: builder, test y runtime |
| `Dockerfile.alpine` | `python:3.12-alpine` | `appuser` (10001) | 79 MB | Reto de tamaño |
| `Dockerfile.distroless` | `distroless/python3-debian12:nonroot` | `nonroot` (65532) | 85 MB | Variante sin shell, para discutir depuración y superficie |

Los tamaños son los observados con Docker 29 en Linux x86-64; pueden variar ligeramente según la versión de la imagen base.

## Notas de diseño

- Las versiones de `flask` y `gunicorn` están fijadas para que el build sea reproducible.
- El `HEALTHCHECK` usa la librería estándar de Python: `python:3.12-slim` no incluye `curl`.
- `Dockerfile` tiene tres etapas: `builder` instala, `test` ejecuta una prueba de humo con `app.test_client()` y `runtime` publica. La etapa final copia `app.py` desde `test`, así que el build falla si la prueba falla.
- La imagen final no lleva compiladores ni caché de pip. Tampoco lleva el resultado de las pruebas: solo se copian `/venv` y `app.py`.
- `Dockerfile.alpine` y `Dockerfile.distroless` mantienen dos etapas para no sumar tiempo al reto. El patrón de test se enseña en el Dockerfile de referencia.
- Distroless no admite `RUN` en la etapa final ni tiene shell: las dependencias se instalan con `--target` en el builder y se copian. El `HEALTHCHECK` va en forma exec porque no hay `/bin/sh`.
- Distroless usa Python 3.11 y `slim` usa 3.12, así que el builder de esa variante es `python:3.11-slim`. Si las versiones no coinciden, las wheels no cargan.
- No hay base de datos: la clase 1 se centra en el ciclo de vida de la imagen.
