import os

from flask import Flask, jsonify

app = Flask(__name__)

VERSION = os.environ.get("APP_VERSION", "dev")

PRODUCTOS = [
    {"id": 1, "nombre": "Teclado", "precio": 25.0},
    {"id": 2, "nombre": "Mouse", "precio": 15.0},
    {"id": 3, "nombre": "Monitor", "precio": 180.0},
]


@app.get("/")
def index():
    return jsonify(servicio="tienda-api", version=VERSION)


@app.get("/healthz")
def healthz():
    return jsonify(status="ok")


@app.get("/productos")
def productos():
    return jsonify(productos=PRODUCTOS)


if __name__ == "__main__":
    # Solo para ejecución local sin gunicorn; en la imagen se usa gunicorn.
    app.run(host="0.0.0.0", port=8000)
