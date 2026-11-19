# Guía paso a paso: Lab 2, del `docker run` a Compose con red separada

| Dato | Valor |
|---|---|
| Duración | 4 h de clase; 100 min de laboratorio (55 min lab 2a + 45 min lab 2b); el paso 7 queda como extensión de 20 min |
| Directorio de trabajo | `clase-02/lab` |
| Imagen de partida | `tienda-api:2.0` (se construye en el paso 2) |
| Disco libre recomendado | 2 GB |
| Entregable | `compose.yaml` funcionando + guía de diagnóstico de red de 10 líneas |

## Qué vas a aprender

Al terminar serás capaz de:

1. Describir un stack de cuatro servicios en un `compose.yaml` y arrancarlo en orden.
2. Separar una red pública de una red interna y comprobar el aislamiento.
3. Diagnosticar DNS, puertos y conectividad con `getent`, `dig` y `netshoot`.
4. Persistir datos en volúmenes y distinguir `down` de `down -v`.
5. Mantener un entorno de desarrollo con override y `docker compose watch`.
6. Explicar por qué dos contenedores no se ven por `localhost`.

## Mapa de pasos

| Paso | Qué haces | Tiempo |
|---|---|---|
| 0 | Verificar el entorno y crear el secreto | 5 min |
| 1 | Leer y validar el `compose.yaml` | 10 min |
| 2 | Arrancar el stack y comprobar el orden | 15 min |
| 3 | Probar la API a través del proxy | 10 min |
| 4 | Ver las redes y el aislamiento | 15 min |
| 5 | Romper el DNS a propósito | 15 min |
| 6 | Volúmenes y persistencia | 10 min |
| 7 | Override de desarrollo, watch y profiles | 20 min |
| 8 | Entregable y limpieza | 10 min |

## Convenciones

- Todos los comandos se ejecutan desde `clase-02/lab`.
- El proxy publica el puerto 18010. La API publica 18011 solo en modo desarrollo. Adminer usa 18012.
- Los comandos están en bash. En PowerShell, consulta el apéndice de la clase 1 y usa `curl.exe`.
- Docker Desktop ejecuta los mismos comandos. La vista Containers agrupa los servicios del proyecto `tienda`; los botones de start, stop y logs equivalen a `docker compose start`, `stop` y `logs`.


## Paso 0. Verificar el entorno y crear el secreto

**Objetivo:** confirmar que Docker y Compose funcionan y preparar el archivo que no debe viajar al repositorio.

```bash
docker version --format 'cliente {{.Client.Version}} / servidor {{.Server.Version}}'
docker compose version
docker run --rm hello-world
```

**Esperado:** cliente y servidor responden, `Docker Compose version v2.x` o superior, y el mensaje `Hello from Docker!`.

Crea el secreto a partir de la plantilla:

```bash
cd clase-02/lab
cp secrets/db_password.txt.example secrets/db_password.txt
```

`secrets/db_password.txt` está en `.gitignore`. El `compose.yaml` lo monta en `/run/secrets/db_password` dentro de Postgres y de la API. Ningún servicio recibe la contraseña por variable de entorno.

**Checkpoint:**

- [ ] `docker compose version` responde.
- [ ] `secrets/db_password.txt` existe.
- [ ] `git status` no muestra ese archivo.


## Paso 1. Leer y validar el `compose.yaml`

**Objetivo:** entender qué servicios hay, cómo se conectan y en qué orden arrancan.

Abre `compose.yaml` y localiza estas piezas:

| Pieza | Qué hace |
|---|---|
| `db` | Postgres 16 con volumen `db_data` y healthcheck `pg_isready` |
| `redis` | Redis 7 con persistencia AOF en `redis_data` |
| `api` | La imagen `tienda-api:2.0`, en las dos redes, sin puerto publicado |
| `proxy` | Nginx en el puerto 18010, solo en `frontend` |
| `adminer` | Interfaz web para la base, solo con el profile `tools` |
| `secrets` | Monta `secrets/db_password.txt` como archivo |
| `networks` | `frontend` normal y `backend` con `internal: true` |

Valida el archivo sin arrancar nada:

```bash
docker compose config --quiet && echo "sintaxis ok"
docker compose config --services
docker compose config --volumes
```

**Esperado:** `sintaxis ok`, los cuatro servicios base (`db`, `redis`, `api`, `proxy`) y los volúmenes `db_data` y `redis_data`. `adminer` no aparece porque está detrás de un profile.

`docker compose config` resuelve variables, rutas y valores por defecto. Si falla, el mensaje indica la línea.

**Checkpoint:**

- [ ] Sabes qué servicio publica el puerto 18010.
- [ ] Sabes qué servicios están en `backend`.
- [ ] `docker compose config` no da errores.


## Paso 2. Arrancar el stack y comprobar el orden

**Objetivo:** ver cómo `depends_on` con `condition: service_healthy` respeta las dependencias.

```bash
docker compose up -d --build
```

**Esperado (resumen):**

```text
Container tienda-db-1 Starting
Container tienda-redis-1 Starting
Container tienda-db-1 Healthy
Container tienda-redis-1 Healthy
Container tienda-api-1 Starting
Container tienda-api-1 Healthy
Container tienda-proxy-1 Starting
```

La API espera a que Postgres y Redis estén sanos. El proxy espera a que la API esté sana. Sin `condition: service_healthy`, Compose solo espera a que el contenedor exista, y la API arrancaría antes de que Postgres acepte conexiones.

Comprueba el estado y los logs:

```bash
docker compose ps
docker compose logs --tail 20 api
docker compose top
```

**Esperado:** `db`, `redis` y `api` en `healthy`; el proxy en `healthy` tras unos segundos. En los logs de la API aparece gunicorn escuchando en `0.0.0.0:8000`: un worker con el override de desarrollo y dos en el modo base.

Si algún servicio queda en `unhealthy`, los logs dicen por qué. `docker compose ps -a` incluye los contenedores parados.

**Checkpoint:**

- [ ] Los cuatro servicios están `Up`.
- [ ] `db`, `redis` y `api` están `healthy`.
- [ ] El orden de arranque se ve en los logs.


## Paso 3. Probar la API a través del proxy

**Objetivo:** comprobar que el proxy es la única entrada pública y que la API usa Postgres y Redis.

```bash
curl -s localhost:18010/
curl -s localhost:18010/productos
curl -s localhost:18010/visitas
curl -s localhost:18010/visitas
curl -s localhost:18010/readyz
```

**Esperado:**

```json
{"db":"ok","redis":"ok","servicio":"tienda-api","version":"dev"}
{"productos":[{"id":1,"nombre":"Teclado","precio":25.0}, ...]}
{"visitas":1}
{"visitas":2}
{"status":"ready"}
```

`version` dice `dev` porque Compose carga también `compose.override.yaml` cuando ejecutas sin `-f`. Para arrancar el modo base, sin override, usa `docker compose -f compose.yaml up -d`; entonces la versión es `2.0` y la API no publica el puerto 18011.

Prueba también el alta de un producto:

```bash
curl -s -X POST localhost:18010/productos \
  -H 'Content-Type: application/json' \
  -d '{"id":4,"nombre":"Webcam","precio":60.0}'
curl -s localhost:18010/productos
```

**Esperado:** `201` con el producto creado y cuatro productos en la lista.

**Checkpoint:**

- [ ] `/` informa `db` y `redis` en `ok`.
- [ ] `/visitas` incrementa.
- [ ] `/readyz` responde `ready`.
- [ ] El POST crea el producto.


## Paso 4. Ver las redes y el aislamiento

**Objetivo:** comprobar que Postgres y Redis no son alcanzables desde la red pública.

Una red de Docker es una red virtual con su propia subred, puerta de enlace y DNS. Un contenedor solo ve a otro si comparte red con él. En este stack:

| Servicio | Redes |
|---|---|
| `proxy` | `frontend` |
| `api` | `frontend`, `backend` |
| `db`, `redis` | `backend` (`internal: true`) |

```bash
docker network ls --filter name=tienda
docker network inspect tienda_backend --format '{{range .Containers}}{{.Name}} {{end}}'
docker network inspect tienda_frontend --format '{{range .Containers}}{{.Name}} {{end}}'
```

**Esperado:**

- `tienda_backend`: `tienda-db-1`, `tienda-redis-1`, `tienda-api-1`.
- `tienda_frontend`: `tienda-api-1`, `tienda-proxy-1`.

`backend` tiene `internal: true`: sus contenedores no tienen salida a Internet. La API sí la tiene porque también está en `frontend`.

Ahora comprueba la resolución de nombres desde dentro:

```bash
docker compose exec -T api getent hosts db
docker compose exec -T proxy sh -c 'getent hosts db || echo "db no existe en frontend"'
```

**Esperado:** la API resuelve `db` a una IP `172.x.x.x`; el proxy no lo encuentra.

Repite la prueba con `netshoot` en cada red:

```bash
docker run --rm --network tienda_backend nicolaka/netshoot \
  sh -c 'nslookup db | tail -3; nc -z -w2 db 5432 && echo "5432 abierto"'

docker run --rm --network tienda_frontend nicolaka/netshoot \
  sh -c 'nslookup db; nc -z -w2 db 5432 || echo "db inalcanzable"'
```

**Esperado:** desde `backend` resuelve y conecta; desde `frontend` la resolución falla con `SERVFAIL`.

La API está en las dos redes porque necesita hablar con el proxy y con la base. El proxy solo necesita hablar con la API. Postgres y Redis solo viven en la red interna.

**Checkpoint:**

- [ ] Sabes qué contenedores hay en cada red.
- [ ] `db` no resuelve desde `frontend`.
- [ ] `db:5432` acepta conexiones desde `backend`.


## Paso 5. Romper el DNS a propósito

**Objetivo:** reconocer los dos errores de red más comunes: un nombre que no existe y `localhost` dentro de un contenedor.

Primero, un nombre inexistente:

```bash
docker run --rm -i --network tienda_backend tienda-api:2.0 python - <<'PY'
import socket
for host in ("db", "basededatos"):
    try:
        print(host, "->", socket.gethostbyname(host))
    except Exception as exc:
        print(host, "-> ERROR:", exc)
PY
```

**Esperado:**

```text
db -> 172.20.0.2
basededatos -> ERROR: [Errno -3] Temporary failure in name resolution
```

El texto exacto cambia según el sistema (`Name or service not known` o `Temporary failure in name resolution`). Lo importante es que el error ocurre antes de abrir la conexión: el nombre no existe en esa red.

Segundo, `localhost` desde dentro de la API:

```bash
docker compose exec -T api python - <<'PY'
import socket
for host in ("localhost", "db"):
    try:
        socket.create_connection((host, 5432), 2)
        print(host, "-> conecta")
    except Exception as exc:
        print(host, "-> ERROR:", exc)
PY
```

**Esperado:** `localhost` da `Connection refused`; `db` conecta. Cada contenedor tiene su propio `localhost`; el de la API no es el de Postgres.

Para diagnosticar un fallo real, este orden funciona:

1. `docker compose ps` para descartar un contenedor parado.
2. `docker compose logs <servicio>` para ver el error de la aplicación.
3. `docker compose exec -T <servicio> getent hosts <nombre>` para comprobar DNS.
4. `docker compose exec -T <servicio> nc -z -w2 <nombre> <puerto>` para comprobar el puerto.
5. `docker network inspect <red>` para confirmar quién está conectado.
6. `netshoot` con `dig`, `tcpdump` o `curl` si hace falta mirar el tráfico.

**Checkpoint:**

- [ ] Distingues error de DNS de error de conexión.
- [ ] Sabes por qué `localhost` no sirve entre contenedores.
- [ ] Tienes un orden de diagnóstico anotado.


## Paso 6. Volúmenes y persistencia

**Objetivo:** comprobar qué sobrevive a un `down` y qué se pierde con `down -v`.

```bash
docker volume ls --filter name=tienda
docker compose exec -T redis redis-cli incr visitas
docker compose down
docker compose up -d --wait
curl -s localhost:18010/visitas
```

**Esperado:** el contador de Redis continúa donde estaba; el producto añadido en el paso 3 sigue en Postgres.

Ahora borra también los volúmenes:

```bash
docker compose down -v
docker compose up -d --wait
curl -s localhost:18010/productos
```

**Esperado:** la lista vuelve a los tres productos de ejemplo. `down -v` elimina los datos; `down` conserva los volúmenes con nombre.

Los bind mounts (`./proxy/nginx.conf`) son archivos del host. Los volúmenes con nombre (`db_data`, `redis_data`) los gestiona Docker y sobreviven al contenedor.

**Checkpoint:**

- [ ] Entiendes la diferencia entre `down` y `down -v`.
- [ ] Los datos de Postgres y Redis sobreviven a `down`.
- [ ] Sabes dónde está cada volumen.


## Paso 7. Override de desarrollo, watch y profiles

**Objetivo:** usar un archivo de override para desarrollo sin tocar el compose base.

El archivo `compose.override.yaml` se carga solo cuando ejecutas `docker compose` sin `-f`. Añade:

- El puerto 18011 en la API.
- `APP_VERSION=dev`.
- `gunicorn --reload` con un solo worker.
- Una regla `develop.watch` que copia los cambios de `app/` al contenedor.

```bash
docker compose up -d
curl -s localhost:18011/
docker compose watch
```

`docker compose watch` se queda en primer plano. En otra terminal, cambia la versión en `app/app.py` o añade un producto de ejemplo y guarda. Watch sincroniza el archivo y gunicorn recarga. Sal con `Ctrl+C`: los contenedores siguen levantados.

Prueba el profile de herramientas:

```bash
docker compose --profile tools up -d
docker compose ps
```

Abre <http://localhost:18012> y entra con:

| Campo | Valor |
|---|---|
| System | PostgreSQL |
| Server | `db` |
| Username | `tienda` |
| Password | el contenido de `secrets/db_password.txt` |
| Database | `tienda` |

Adminer está en `backend` para hablar con Postgres y en `frontend` para que Docker pueda publicar el puerto. Un contenedor conectado solo a una red `internal` no recibe mapeo de puertos.

**Checkpoint:**

- [ ] El override publica 18011 y cambia la versión.
- [ ] `docker compose watch` sincroniza un cambio.
- [ ] Adminer abre y lista la tabla `productos`.

Si terminas antes, [`lab-2c.md`](lab-2c.md) amplía este paso con copia de seguridad de Postgres y redes a mano.


## Paso 8. Entregable y limpieza

Entrega:

1. El `compose.yaml` que arranca con `docker compose up -d --build` y deja los cuatro servicios sanos.
2. Una guía de diagnóstico de 10 líneas con el orden del paso 5 y al menos dos comandos de `netshoot`.
3. La salida de `docker network inspect tienda_backend` y `tienda_frontend`.
4. Una frase que explique por qué el proxy no está en `backend`.

Limpieza:

```bash
docker compose --profile tools down
docker rmi tienda-api:2.0 2>/dev/null || true
```

No borres volúmenes de otros compañeros. Si trabajas en un host compartido, usa un `name:` de proyecto propio, por ejemplo `tienda-tunombre`, y puertos distintos.

Rúbrica: [`../evaluacion/rubrica-clase-02.md`](../evaluacion/rubrica-clase-02.md).

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `port is already allocated` en 18010 | Otro proceso o contenedor usa el puerto | Cambia el puerto izquierdo en `compose.yaml` y en el override |
| `db` en `unhealthy` | Contraseña o volumen con datos de otra prueba | `docker compose logs db`; si el volumen es de prueba, `docker compose down -v` |
| La API arranca y muere | No encuentra Postgres o el secreto | `docker compose logs api`; revisa `depends_on`, el secreto y `DATABASE_HOST` |
| `password authentication failed` | El volumen conserva la contraseña anterior | `docker compose down -v` y vuelve a arrancar |
| `nginx: host not found in upstream "api"` | El proxy arrancó antes que la API | Revisa `depends_on` con `service_healthy`; reinicia el proxy |
| `curl` devuelve 502 | Nginx vive, la API no | `docker compose ps` y `docker compose logs api` |
| `/visitas` da 503 | Redis no responde | `docker compose exec redis redis-cli ping` |
| Cambios en `app.py` no se ven | No estás usando el override o watch | `docker compose up -d` sin `-f` y `docker compose watch` |
| Adminer no aparece | Falta el profile | `docker compose --profile tools up -d` |
| Un puerto publicado no responde | El contenedor solo está en una red `internal` | Añádelo también a `frontend`; Docker necesita una red con salida para publicar |
| `down -v` borró los datos | Es el comportamiento esperado | Los volúmenes con nombre son la única copia local |

## Apéndice A. Chuleta de comandos

```bash
# Ciclo de vida
docker compose up -d --build
docker compose ps
docker compose logs -f --tail 50 api
docker compose exec -T api sh
docker compose stop
docker compose start
docker compose down
docker compose down -v

# Validar y ver
docker compose config
docker compose config --services
docker compose top
docker compose images

# Desarrollo
docker compose watch
docker compose --profile tools up -d

# Redes
docker network ls --filter name=tienda
docker network inspect tienda_backend
docker run --rm --network tienda_backend nicolaka/netshoot \
  sh -c 'nslookup db; nc -z -w2 db 5432 && echo abierto'
docker run --rm --network tienda_frontend nicolaka/netshoot \
  sh -c 'curl -s -o /dev/null -w "%{http_code}\n" http://api:8000/healthz'

# Volúmenes
docker volume ls --filter name=tienda
docker volume inspect tienda_db_data
```

## Apéndice B. Resultados medidos

| Comprobación | Resultado |
|---|---|
| Servicios sanos | `db`, `redis`, `api`, `proxy` |
| Proxy | `18010 -> 80/tcp` |
| API en modo dev | `18011 -> 8000/tcp` |
| Contenedores en `tienda_backend` | `db`, `redis`, `api` |
| Contenedores en `tienda_frontend` | `api`, `proxy` |
| `db` desde `frontend` | `SERVFAIL` |
| `db:5432` desde `backend` | conexión aceptada |
| `localhost:5432` desde `api` | `Connection refused` |
| Persistencia tras `down` | se conserva |
| Persistencia tras `down -v` | se pierde |

Los tiempos de arranque varían según la máquina, sobre todo la primera vez que se descargan las imágenes.

## Apéndice C. Qué hace cada decisión del compose

- `internal: true` en `backend` evita que Postgres y Redis salgan a Internet. La API mantiene salida por `frontend`.
- `depends_on` con `condition: service_healthy` convierte el healthcheck en una dependencia real. Un simple `depends_on: [db]` solo espera a que el contenedor exista.
- Los secretos se montan como archivos. La contraseña no aparece en `docker inspect` ni en `docker compose config` resueltos.
- El proxy monta su configuración como bind mount de solo lectura. Cambiar `nginx.conf` requiere `docker compose restart proxy`.
- Los volúmenes tienen nombre explícito (`tienda_db_data`) para que los comandos del laboratorio sean predecibles y los datos no se confundan con otros proyectos.
- Adminer vive detrás de un profile para que no arranque en el flujo normal ni ocupe un puerto.
