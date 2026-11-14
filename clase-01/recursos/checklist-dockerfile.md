# Checklist de Dockerfile (imprimible)

## Base

- [ ] Imagen base fijada por versión (`python:3.12-slim`), nunca `latest`.
- [ ] La base más pequeña que siga siendo compatible (slim > alpine > distroless, según dependencias).
- [ ] Un solo proceso principal por contenedor.

## Contexto y capas

- [ ] `.dockerignore` con `.git`, `venv`, `__pycache__`, `node_modules`, secretos.
- [ ] Primero `COPY` de dependencias + instalación; después el código.
- [ ] `RUN` que se puedan combinar, combinados (menos capas, menos peso).
- [ ] `--no-cache-dir` (pip), `npm ci`, `apt-get ... && rm -rf /var/lib/apt/lists/*`.
- [ ] Nada de borrar archivos en una capa posterior para "reducir": no reduce.

## Multi-stage

- [ ] Herramientas de build solo en la etapa `builder`.
- [ ] La etapa final copia únicamente artefactos (`COPY --from=builder`).
- [ ] Sin compiladores, tests, cachés ni credenciales en la imagen final.

## Seguridad

- [ ] `USER` no root con UID fijo.
- [ ] Sin secretos en `ENV`, `ARG`, `COPY` ni `RUN` (quedan en el historial).
- [ ] Versiones de dependencias fijadas (`flask==3.0.3`).
- [ ] `HEALTHCHECK` apuntando a un endpoint real.
- [ ] `CMD`/`ENTRYPOINT` en forma exec (`["gunicorn", ...]`), no shell.

## Metadatos

- [ ] `EXPOSE` coincide con el puerto real.
- [ ] `WORKDIR` absoluto.
- [ ] Etiquetas (`LABEL`) de versión/repositorio si el registro las usa.

## Verificación

- [ ] La imagen arranca y responde.
- [ ] `docker exec <c> id` no es root.
- [ ] `docker history` no muestra capas innecesarias.
- [ ] Tamaño y tiempo de build anotados.
