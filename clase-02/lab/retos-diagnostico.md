# Retos de diagnóstico: clase 2

Cuatro averías para resolver en parejas. Todas se hacen sobre el stack de `clase-02/lab` y se deshacen al final.

| Dato | Valor |
|---|---|
| Duración | 25 min (bloque de cierre) |
| Directorio | `clase-02/lab` |
| Requisito | Stack sano y `secrets/db_password.txt` creado |
| Formato | Parejas: una persona ejecuta, la otra lee la salida y decide |

## Reglas

- No uses `docker compose down -v` salvo en el reto 4 y solo si eliges el camino destructivo.
- Antes de tocar nada, apunta el estado: `docker compose ps`.
- Para cada reto escribe tres líneas: síntoma, causa y comando que lo confirma.
- Si un comando tarda, sigue leyendo la salida en otra terminal. No borres contenedores a ciegas.

## Reto 1. El proxy devuelve 504 (5 min)

**Síntoma:** el proxy responde 504 y la API no está en la lista de contenedores activos.

```bash
docker compose stop api
curl -s -o /dev/null -w '%{http_code}\n' localhost:18010/
docker compose ps -a
docker compose logs --tail=5 proxy
```

**Esperado:** `504`, la API en estado `exited` y en los logs de Nginx algo como:

```text
upstream timed out (110: Operation timed out) while connecting to upstream
```

**Diagnóstico:** Nginx resolvió `api` al arrancar y guardó su IP. Al parar el contenedor esa IP deja de responder, pero nadie rechaza la conexión: el proxy espera hasta que vence `proxy_connect_timeout 3s` y devuelve 504. Un 502 sería un rechazo explícito o una respuesta inválida del upstream, como en el reto 3.

**Arreglo:** arranca el mismo contenedor para conservar su IP y espera el healthcheck:

```bash
docker compose start api
for i in $(seq 1 30); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q api)")" = healthy ] && break
  sleep 2
done
curl -s localhost:18010/healthz
```

No uses `docker compose up` aquí: puede recrear el contenedor y cambiar la IP que Nginx ya tiene guardada.

**Comprobación:** `curl -s localhost:18010/` devuelve 200 y `db` y `redis` aparecen en `ok`.

## Reto 2. El host de la base no existe (7 min)

**Síntoma:** la API arranca, pero la base aparece en error. El nombre del servicio se cambió a `database`, que no existe.

Crea un overlay temporal y recrea solo la API:

```bash
cat > /tmp/db-roto.yaml <<'YAML'
services:
  api:
    environment:
      DATABASE_HOST: database
    ports:
      - "18011:8000"
YAML

docker compose -f compose.yaml -f /tmp/db-roto.yaml up -d api
sleep 70
curl -s localhost:18011/readyz
curl -s localhost:18011/
```

**Esperado:** el primer `curl` devuelve 503 y un texto parecido a:

```json
{"status":"not-ready","error":"could not translate host name \"database\" to address: Temporary failure in name resolution"}
```

Puede decir `Name or service not known` según el sistema. El segundo devuelve `"db":"error"` y `"redis":"ok"`.

**Por qué tarda:** la API reintenta la conexión 30 veces con 2 segundos entre intentos antes de empezar a escuchar. Es un fallo de arranque, no de puerto.

**Diagnóstico:** el nombre `database` no existe en la red `frontend`. La API está en `frontend` y `backend`; la base solo en `backend`. El nombre correcto es `db`.

**Arreglo:** vuelve al compose normal y recrea API y proxy para que Nginx apunte a la IP nueva:

```bash
docker compose up -d --force-recreate api proxy
curl -s localhost:18010/readyz
```

**Comprobación:** `{"status":"ready"}`.

## Reto 3. El proxy apunta al puerto equivocado (5 min)

**Síntoma:** un proxy alternativo devuelve 502, pero la API está sana.

```bash
cat > /tmp/nginx-8001.conf <<'CONF'
server {
    listen 80;
    location / {
        proxy_pass http://api:8001;
    }
}
CONF

docker run -d --rm --name proxy-roto \
  --network tienda_frontend \
  -p 18015:80 \
  -v /tmp/nginx-8001.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx:1.27-alpine

sleep 2
curl -s -o /dev/null -w '%{http_code}\n' localhost:18015/
docker logs --tail=3 proxy-roto
```

**Esperado:** `502` y un log con `connect() failed (111: Connection refused)` contra una IP `172.x.x.x:8001`.

**Diagnóstico:** el nombre `api` se resolvió, así que no es DNS. La API escucha en 8000, no en 8001. Este es el error que se comete al copiar un `docker run -p 8000:8000` y confundir el puerto del contenedor con el del host.

**Arreglo:** cambia `8001` por `8000` en `/tmp/nginx-8001.conf` y reinicia el contenedor, o simplemente retíralo:

```bash
docker rm -f proxy-roto
```

**Comprobación:** si cambias el puerto a `8000` y reinicias `proxy-roto`, `curl -s localhost:18015/` devuelve 200. La API no se tocó en ningún momento.

## Reto 4. La contraseña nueva no entra (8 min)

**Síntoma:** se cambió el secreto, pero Postgres sigue autenticando con el anterior.

```bash
cp secrets/db_password.txt /tmp/db_password.bak
printf 'clave-nueva\n' > secrets/db_password.txt
docker compose up -d --force-recreate api proxy
sleep 70
curl -s localhost:18010/
curl -s localhost:18011/readyz
```

**Esperado:** `"db":"error"` en `/` y en `/readyz`:

```text
password authentication failed for user "tienda"
```

**Diagnóstico:** el volumen `tienda_db_data` ya estaba inicializado. `POSTGRES_PASSWORD_FILE` solo se usa la primera vez que se crea el directorio de datos. Cambiar el archivo del secreto cambia lo que envía la API, no la contraseña guardada en Postgres.

**Arreglo recomendado:** restaurar el secreto anterior y recrear la API. No se pierden datos.

```bash
cp /tmp/db_password.bak secrets/db_password.txt
docker compose up -d --force-recreate api
curl -s localhost:18010/
```

**Camino alternativo, solo en laboratorio:** aceptar la contraseña nueva y recrear la base desde cero. Borra los datos.

```bash
printf 'clave-nueva\n' > secrets/db_password.txt
docker compose down -v
docker compose up -d --wait
```

**Comprobación:** `"db":"ok"` y los productos siguen ahí si elegiste el arreglo recomendado.

## Restaurar el entorno

```bash
rm -f /tmp/db-roto.yaml /tmp/nginx-8001.conf
docker rm -f proxy-roto 2>/dev/null || true
docker compose up -d --force-recreate api proxy
docker compose ps
```

Si el reto 4 quedó a medias, restaura el secreto y recrea:

```bash
cp /tmp/db_password.bak secrets/db_password.txt 2>/dev/null || true
docker compose up -d --force-recreate
```

## Checklist de cierre

- [ ] Distingo 502, 503 y 504 y sé qué capa responde cada uno.
- [ ] Sé diferenciar un fallo de DNS de un puerto cerrado.
- [ ] Sé qué comando confirma la IP y el puerto de un upstream.
- [ ] Sé por qué cambiar el secreto no cambia la contraseña de una base ya inicializada.
- [ ] Dejé el stack sano y sin overlays temporales.
