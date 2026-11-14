# Checklist de `compose.yaml`

Úsalo antes de entregar el lab 2. Cada casilla debe poder demostrarse con un comando.

## Servicios

- [ ] Cada servicio tiene un nombre que describe su función (`db`, `redis`, `api`, `proxy`).
- [ ] Las imágenes usan una versión fija o un digest, no `latest`.
- [ ] La API se construye desde `./app` y la imagen tiene etiqueta propia.
- [ ] Solo el proxy publica un puerto al host.
- [ ] La API no publica puertos en el compose base.

## Salud y orden

- [ ] Postgres tiene `pg_isready` como healthcheck.
- [ ] Redis responde a `redis-cli ping`.
- [ ] La API comprueba `/healthz`.
- [ ] `depends_on` usa `condition: service_healthy` donde importa.
- [ ] El proxy espera a que la API esté sana.

## Redes

- [ ] Hay una red `frontend` y una `backend`.
- [ ] `backend` tiene `internal: true`.
- [ ] Postgres y Redis solo están en `backend`.
- [ ] El proxy solo está en `frontend`.
- [ ] La API está en las dos.
- [ ] Los nombres de red son predecibles o están documentados.

## Datos

- [ ] Postgres guarda en un volumen con nombre.
- [ ] Redis guarda en un volumen con nombre.
- [ ] Sabes qué borra `down` y qué borra `down -v`.

## Secretos y configuración

- [ ] La contraseña está en un archivo montado en `/run/secrets`.
- [ ] Ese archivo está en `.gitignore`.
- [ ] La configuración no secreta usa variables de entorno o `env_file`.
- [ ] Ningún secreto aparece en la imagen ni en `docker inspect`.

## Desarrollo

- [ ] Existe `compose.override.yaml` para desarrollo.
- [ ] El override publica solo lo necesario (por ejemplo, la API en 18011).
- [ ] `docker compose watch` está configurado o explicado.
- [ ] Las herramientas opcionales están detrás de un profile.

## Operación

- [ ] `docker compose config --quiet` pasa.
- [ ] `docker compose up -d --build` deja todo sano.
- [ ] `docker compose logs` muestra errores entendibles.
- [ ] La guía de diagnóstico tiene 10 líneas y comandos ejecutables.
