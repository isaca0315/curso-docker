# Clase 2: hora extra

Material de reserva para cuando el grupo termina antes de las 4 horas. Son tres bloques de 20 minutos que no dependen entre sí y no repiten [`lab/lab-2c.md`](lab/lab-2c.md), que cubre override, copia de seguridad y redes a mano. Aquí se ven DNS, tráfico real y reutilización del YAML.

El stack tiene que estar arriba en `clase-02/lab` con `docker compose up -d --wait`. Los nombres de contenedor (`tienda-api-1`, `tienda-db-1`) salen del proyecto fijo `tienda`.

## Bloque 1. DNS a fondo (20 min)

**Qué se explica:** cada contenedor consulta al DNS de Docker en `127.0.0.11`. Ese servidor responde por nombre de servicio, y el aislamiento se nota primero en la resolución.

Dentro de la API:

```bash
docker compose exec -T api cat /etc/resolv.conf
docker compose exec -T api getent hosts db
```

**Esperado:** `nameserver 127.0.0.11` y una línea `search` con los dominios del host. `getent` devuelve la IP de `db` en `backend`, por ejemplo `172.20.0.2`.

El mismo nombre desde las dos redes:

```bash
docker run --rm --network tienda_backend nicolaka/netshoot sh -c 'dig +short db; dig +short redis'
docker run --rm --network tienda_frontend nicolaka/netshoot sh -c 'dig +short api; dig db +time=2 +tries=1 | grep "status:"'
```

**Esperado:** desde `backend` salen las IP de `db` y `redis`. Desde `frontend` sale la IP de `api`, y `db` responde `SERVFAIL` porque no está en esa red.

El nombre sobrevive a los cambios de IP:

```bash
docker network inspect tienda_backend --format '{{range .Containers}}{{.Name}}={{.IPv4Address}} {{end}}'
```

**Esperado:** cada contenedor con su IP dentro de `172.20.x.x`. Si un contenedor se recrea, el DNS devuelve la IP nueva y los clientes que usan el nombre siguen igual. Por eso Nginx necesita reiniciarse cuando cambia la IP de `api`; guarda la dirección al arrancar.

Para llegar a un servicio del host desde un contenedor, Linux necesita una entrada explícita:

```bash
cat > /tmp/extra-host.yaml <<'YAML'
services:
  api:
    extra_hosts:
      - "host.docker.internal:host-gateway"
YAML

docker compose -f compose.yaml -f /tmp/extra-host.yaml up -d --wait api
docker compose exec -T api getent hosts host.docker.internal
```

**Esperado:** `172.17.0.1  host.docker.internal`, la puerta de enlace del bridge por defecto. En Docker Desktop el nombre ya existe y esta entrada no hace falta.

Vuelve al compose normal:

```bash
docker compose up -d --wait --force-recreate api proxy
rm -f /tmp/extra-host.yaml
```

Si sobra tiempo en el bloque, prueba `dns: [9.9.9.9]` en el servicio `api`. Docker mantiene `127.0.0.11` para los nombres internos y usa el servidor indicado para los externos; el cambio se ve en la línea `ExtServers` de `resolv.conf`.

**Checkpoint:** el alumno explica por qué `db` resuelve desde `backend` y no desde `frontend`, y por qué el proxy puede dejar de ver la API después de recrearla sin reiniciar Nginx.

## Bloque 2. tcpdump: las dos conexiones del puerto publicado (20 min)

**Qué se explica:** una petición a `localhost:18010` entra por el host, se traduce a la red de `frontend` y el proxy abre otra conexión hacia la API. Son dos conexiones distintas y `tcpdump` permite verlas.

Captura dentro del espacio de red de la API:

```bash
docker run -d --name captura --net=container:tienda-api-1 \
  --cap-add NET_ADMIN --cap-add NET_RAW nicolaka/netshoot \
  tcpdump -i any -nn -c 20 'port 53 or port 5432 or port 6379'

sleep 2
curl -s localhost:18010/ >/dev/null
sleep 2
docker logs captura 2>&1 | grep -E 'A 172|: Flags \[S\]'
docker rm -f captura
```

**Esperado:** dos respuestas de `127.0.0.11.53`, una con la IP de `db` y otra con la de `redis`, y un `SYN` hacia la IP de `db` en el 5432 y otro hacia la de `redis` en el 6379. Se ven la consulta DNS y las dos conexiones que abre `/` para comprobar Postgres y Redis.

Captura en el host:

```bash
docker run -d --name captura-host --net=host \
  --cap-add NET_ADMIN --cap-add NET_RAW nicolaka/netshoot \
  tcpdump -i any -nn -c 10 'port 18010 or port 8000'

sleep 2
curl -4 -s localhost:18010/ >/dev/null
sleep 2
docker logs captura-host 2>&1 | grep -E '18010|8000' | head -6
docker rm -f captura-host
```

**Esperado:** primero `127.0.0.1.xxxxx > 127.0.0.1.18010` en `lo`, y después una conexión desde la IP del proxy a la de la API en el 8000, sobre una interfaz `veth`. La primera conexión termina en el proxy; la segunda la abre el proxy hacia la API. La API nunca ve el puerto 18010.

En Docker Desktop, `--net=host` no siempre muestra la misma vista; si falla, el bloque sigue con la captura dentro de la API, que es la parte que importa.

**Checkpoint:** el alumno distingue la conexión del host al puerto publicado de la conexión interna entre proxy y API, y sabe en qué interfaz capturar cada una.

## Bloque 3. Anclas YAML y extends (20 min)

**Qué se explica:** las anclas repiten un bloque dentro de un archivo y `extends` lo reutiliza desde otro. Sirven para no copiar el mismo healthcheck o la misma política de logs en cada servicio.

Ancla de registro aplicada a dos servicios:

```bash
cat > /tmp/anclas.yaml <<'YAML'
x-registro: &registro
  logging:
    driver: json-file
    options:
      max-size: "1m"
      max-file: "2"

services:
  api:
    <<: *registro
  proxy:
    <<: *registro
YAML

docker compose -f compose.yaml -f /tmp/anclas.yaml config | grep -c 'max-size'
docker compose -f compose.yaml -f /tmp/anclas.yaml up -d --wait
docker inspect tienda-api-1 --format '{{json .HostConfig.LogConfig}}'
docker inspect tienda-proxy-1 --format '{{json .HostConfig.LogConfig}}'
```

**Esperado:** el `grep` cuenta tres apariciones (la definición del ancla y los dos servicios). Los dos `inspect` muestran `{"Type":"json-file","Config":{"max-file":"2","max-size":"1m"}}`.

Los campos que empiezan con `x-` no son servicios: Compose los ignora y quedan disponibles como ancla. Con `<<: *registro` el bloque se copia en cada servicio. Si un servicio repite una de esas claves, manda la del servicio.

Vuelve al compose normal:

```bash
docker compose up -d --wait --force-recreate api proxy
rm -f /tmp/anclas.yaml
```

`extends` lee la definición desde otro archivo:

```bash
cat > /tmp/base.yaml <<'YAML'
services:
  web:
    image: nginx:1.27-alpine
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost/"]
      interval: 10s
      timeout: 3s
      retries: 3
YAML

cat > /tmp/extra-web.yaml <<'YAML'
services:
  web:
    extends:
      file: /tmp/base.yaml
      service: web
    ports:
      - "18013:80"
YAML

docker compose -p extra-web -f /tmp/extra-web.yaml up -d --wait
curl -s -o /dev/null -w '%{http_code}\n' localhost:18013/
docker compose -p extra-web -f /tmp/extra-web.yaml down
rm -f /tmp/base.yaml /tmp/extra-web.yaml
```

**Esperado:** `200` en el puerto 18013 y el proyecto `extra-web` eliminado al final. El healthcheck viene del archivo base y el puerto se agrega en el archivo local.

Un ancla solo existe dentro de su archivo. `extends` cruza archivos y Compose resuelve la definición al leer el proyecto.

**Checkpoint:** el alumno reutiliza un bloque con ancla en el mismo archivo y con `extends` entre archivos, y sabe cuál de las dos opciones usar según dónde viva la definición.

## Si solo hay 20 minutos

Haz el bloque 1. El DNS es lo primero que se revisa cuando un servicio no encuentra a otro y no necesita archivos temporales más allá del override.

## Si hay 40 minutos

Bloques 1 y 2. El 3 se puede mandar como deberes con los mismos comandos.
