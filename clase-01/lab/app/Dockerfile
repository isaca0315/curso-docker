# Imagen optimizada: multi-stage, slim, usuario sin privilegios.
# Etapa 1: construir dependencias. Se descarta al final.
FROM python:3.12-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN python -m venv /venv \
    && /venv/bin/pip install --no-cache-dir -r requirements.txt

# Etapa 2: probar la app antes de publicarla. Si falla, el build se detiene.
FROM python:3.12-slim AS test

ENV PATH="/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY --from=builder /venv /venv
COPY app.py .
RUN python -c "from app import app; c = app.test_client(); \
    assert c.get('/healthz').status_code == 200; \
    assert c.get('/productos').get_json()['productos']; \
    assert c.get('/').get_json()['servicio'] == 'tienda-api'"

# Etapa 3: ejecución. Empieza de cero con la base mínima.
FROM python:3.12-slim AS runtime

ENV PATH="/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
# Del builder solo viaja el virtualenv, no el compilador ni la caché.
COPY --from=builder /venv /venv
# Se copia desde test para que Docker ejecute esa etapa y valide la app.
COPY --from=test /app/app.py .

USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')"

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
