import os
import time

import psycopg2
import redis
from flask import Flask, jsonify, request

app = Flask(__name__)

VERSION = os.environ.get("APP_VERSION", "dev")
SEED = [
    (1, "Teclado", 25.0),
    (2, "Mouse", 15.0),
    (3, "Monitor", 180.0),
]


def db_password():
    value = os.environ.get("DB_PASSWORD")
    if value:
        return value
    path = os.environ.get("DB_PASSWORD_FILE")
    if path and os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            return fh.read().strip()
    return ""


def db():
    return psycopg2.connect(
        host=os.environ.get("DATABASE_HOST", "db"),
        port=os.environ.get("DATABASE_PORT", "5432"),
        dbname=os.environ.get("DATABASE_NAME", "tienda"),
        user=os.environ.get("DATABASE_USER", "tienda"),
        password=db_password(),
        connect_timeout=3,
    )


def cache():
    return redis.Redis.from_url(
        os.environ.get("REDIS_URL", "redis://redis:6379/0"), socket_timeout=3
    )


def init_db():
    # Compose arranca la API cuando Postgres está sano, pero el primer
    # arranque de la base todavía puede tardar unos segundos.
    for _ in range(30):
        try:
            with db() as conn, conn.cursor() as cur:
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS productos (
                        id integer PRIMARY KEY,
                        nombre text NOT NULL,
                        precio numeric(10, 2) NOT NULL
                    )
                    """
                )
                cur.execute("SELECT count(*) FROM productos")
                if cur.fetchone()[0] == 0:
                    cur.executemany(
                        "INSERT INTO productos (id, nombre, precio) VALUES (%s, %s, %s)",
                        SEED,
                    )
            return True
        except Exception:
            time.sleep(2)
    return False


init_db()


@app.get("/")
def index():
    estado = {"db": "ok", "redis": "ok"}
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
    except Exception:
        estado["db"] = "error"
    try:
        cache().ping()
    except Exception:
        estado["redis"] = "error"
    return jsonify(servicio="tienda-api", version=VERSION, **estado)


@app.get("/healthz")
def healthz():
    return jsonify(status="ok")


@app.get("/readyz")
def readyz():
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        cache().ping()
    except Exception as exc:
        return jsonify(status="not-ready", error=str(exc)), 503
    return jsonify(status="ready")


@app.get("/productos")
def productos():
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute("SELECT id, nombre, precio FROM productos ORDER BY id")
            filas = [
                {"id": i, "nombre": n, "precio": float(p)} for i, n, p in cur.fetchall()
            ]
    except Exception as exc:
        return jsonify(error=str(exc)), 503
    return jsonify(productos=filas)


@app.get("/visitas")
def visitas():
    try:
        total = cache().incr("visitas")
    except Exception as exc:
        return jsonify(error=str(exc)), 503
    return jsonify(visitas=int(total))


@app.post("/productos")
def crear_producto():
    datos = request.get_json(silent=True) or {}
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO productos (id, nombre, precio) VALUES (%s, %s, %s)",
                (datos["id"], datos["nombre"], datos["precio"]),
            )
    except Exception as exc:
        return jsonify(error=str(exc)), 400
    return jsonify(creado=datos), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
