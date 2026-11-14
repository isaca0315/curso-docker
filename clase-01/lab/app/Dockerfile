# Imagen optimizada: multi-stage, slim, usuario sin privilegios.
FROM python:3.12-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN python -m venv /venv \
    && /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim

ENV PATH="/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
COPY --from=builder /venv /venv
COPY app.py .

USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz')"

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
