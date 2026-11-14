---
marp: true
theme: default
paginate: true
header: "Docker Avanzado · Clase 2"
---

# Docker Avanzado

## Clase 2: Compose y networking avanzado

4 horas · 6 participantes · Stack `tienda-api` + Postgres + Redis + Nginx

---

# Contenido

1. Describir un stack multi-contenedor con Compose
2. Arrancar en orden con healthchecks
3. Separar redes y comprobar el aislamiento
4. Diagnosticar DNS, puertos y conectividad
5. Entornos de desarrollo con override y watch

**Hilo del curso:** hoy el stack se levanta con Compose; en la clase 3 se orquesta en Kubernetes.

---

# De `docker run` a Compose

```bash
docker network create tienda_backend
docker volume create tienda_db_data
docker run -d --name db --network tienda_backend \
  -e POSTGRES_PASSWORD=... -v tienda_db_data:/var/lib/postgresql/data postgres:16-alpine
docker run -d --name redis --network tienda_backend redis:7-alpine
docker run -d --name api --network tienda_backend ...
```

Cuatro servicios, seis comandos y ningún registro de lo que depende de qué.

Compose guarda ese estado en un archivo versionado.

---

# Un `compose.yaml` mínimo

```yaml
name: tienda

services:
  api:
    build: ./app
    ports:
      - "18010:8000"
    environment:
      REDIS_URL: redis://redis:6379/0
    depends_on:
      redis:
        condition: service_healthy

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
```

`docker compose up -d` crea servicios, red y volúmenes con el prefijo del proyecto.

---

# Las cuatro secciones que importan

| Sección | Qué declara |
|---|---|
| `services` | Contenedores, imagen, puertos, entorno, salud |
| `networks` | Redes y su alcance (`internal`, driver) |
| `volumes` | Datos que sobreviven al contenedor |
| `secrets` | Archivos montados en `/run/secrets` |

`docker compose config` resuelve el archivo final. Úsalo antes de arrancar.

---

# Orden de arranque real

```yaml
depends_on:
  db:
    condition: service_healthy
  redis:
    condition: service_healthy
```

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U tienda -d tienda"]
  interval: 5s
  timeout: 3s
  retries: 10
```

Sin `condition`, Compose solo espera a que el contenedor exista. Postgres tarda segundos en aceptar conexiones.

---

# `service_healthy` en la práctica

```text
db Starting -> Healthy
redis Starting -> Healthy
api Starting -> Healthy
proxy Starting
```

La API espera a la base. El proxy espera a la API.

Regla: un healthcheck comprueba el servicio, no solo el proceso. `pg_isready` consulta la base; un `sleep` no comprueba nada.

---

# Redes: la default no tiene DNS

| Red | DNS por nombre | Aislamiento |
|---|---|---|
| `bridge` (default) | No | Todos los contenedores se ven |
| User-defined bridge | Sí, por nombre de servicio | Solo los de esa red |
| `host` | Resolución del host | Sin aislamiento de red |
| `none` | Solo loopback | Sin red |

Compose siempre crea redes user-defined. Por eso `api` resuelve `db` sin configurar nada.

---

# DNS embebido

```text
contenedor api
  /etc/resolv.conf -> 127.0.0.11
        |
        v
  Docker DNS (por red)
        |
        +--> db      -> 172.20.0.2
        +--> redis   -> 172.20.0.3
        +--> api     -> 172.20.0.4
```

El nombre es el servicio o un `alias`. La IP cambia cuando el contenedor se recrea; el nombre no.

---

# Aislamiento frontend / backend

```text
        host :18010
             |
        [ proxy ]        red frontend
             |
          [ api ]        frontend + backend
           /     \
      [ db ]   [ redis ]  red backend (internal)
```

- El proxy no alcanza la base.
- La base no sale a Internet.
- La API es el único puente entre las dos redes.

---

# Volúmenes: qué sobrevive

| Acción | Contenedor | Volumen |
|---|---|---|
| `docker compose stop` | se para | se conserva |
| `docker compose down` | se borra | se conserva |
| `docker compose down -v` | se borra | se borra |
| `docker compose up -d` | se recrea | se reutiliza |

Los bind mounts (`./proxy/nginx.conf`) son archivos del host. Los volúmenes con nombre los gestiona Docker.

---

# Secretos

```yaml
services:
  db:
    secrets: [db_password]
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

- El archivo no se versiona.
- La contraseña no aparece en `docker inspect`.
- `docker compose config` muestra la ruta, no el contenido.
- En producción: Docker secrets, Vault, SOPS o el gestor del cloud.

---

# Override y profiles

`compose.override.yaml` se carga automáticamente:

```bash
docker compose up -d                      # base + override (dev)
docker compose -f compose.yaml up -d      # solo base (prod-like)
```

Profiles para herramientas que no siempre hacen falta:

```yaml
adminer:
  profiles: ["tools"]
```

```bash
docker compose --profile tools up -d
```

---

# `docker compose watch`

```yaml
develop:
  watch:
    - action: sync
      path: ./app
      target: /app
```

```bash
docker compose watch
```

Sincroniza archivos y reinicia o reconstruye según la regla. Gunicorn con `--reload` recarga el código sin reiniciar el contenedor.

---

# Drivers de red

| Driver | Uso |
|---|---|
| `bridge` | Predeterminado en un host |
| `host` | Sin NAT; comparte la pila del host |
| `none` | Aislamiento total de red |
| `macvlan` | IP de la LAN, el contenedor es un vecino más |
| `overlay` | Varios hosts (Swarm) |

`macvlan` necesita una interfaz del host en la LAN y un switch que permita varias MAC.

---

# `host`, `none` y `macvlan`

```bash
# host: el proceso ve los puertos del host
docker run --rm --network host nginx:1.27-alpine

# none: solo loopback
docker run --rm --network none alpine ip addr

# macvlan: IP de la LAN (ejemplo, ajustar interfaz y rango)
docker network create -d macvlan \
  --subnet 192.168.1.0/24 --gateway 192.168.1.1 \
  -o parent=eth0 lan
```

`host` pierde el aislamiento y el mapeo de puertos. `macvlan` no habla con el host por defecto.

---

# Publicar puertos no es abrir un firewall

```yaml
ports:
  - "18010:80"
```

- Docker crea una regla DNAT de 18010 a la IP del contenedor.
- `EXPOSE` solo documenta; no publica.
- Sin `ports`, el servicio solo es alcanzable desde sus redes.
- `internal: true` bloquea la salida a Internet de esa red.

---

# Diagnóstico: orden que funciona

1. `docker compose ps`
2. `docker compose logs <servicio>`
3. `getent hosts <nombre>` dentro del contenedor
4. `nc -z -w2 <nombre> <puerto>`
5. `docker network inspect <red>`
6. `netshoot` con `dig`, `curl` o `tcpdump`

Cada paso descarta una capa: proceso, aplicación, DNS, puerto, pertenencia a la red.

---

# `netshoot`

```bash
docker run --rm -it --network tienda_backend nicolaka/netshoot

nslookup db
dig redis
nc -zv db 5432
curl -s http://api:8000/healthz
tcpdump -i any port 5432
```

La misma imagen sirve para comprobar la red desde fuera de los servicios.

---

# Lab 2a (50 min)

Stack completo con Compose:

1. Crear el secreto y validar el YAML
2. Arrancar y comprobar el orden
3. Probar la API por el proxy
4. Ver las redes y el aislamiento
5. Volúmenes y persistencia
6. Override de desarrollo

Guía: `lab/guia-paso-a-paso.md`

---

# Lab 2b (60 min)

1. Resolver `db` desde `backend` y fallar desde `frontend`
2. Romper un nombre a propósito y leer el error
3. Comprobar que `localhost` no cruza contenedores
4. Capturar tráfico con `netshoot`
5. Comparar `host` y bridge
6. `macvlan` en la LAN del aula (opcional)

Entregable: guía de diagnóstico de 10 líneas.

---

# Errores típicos

| Síntoma | Causa |
|---|---|
| `502 Bad Gateway` | La API no está sana o no resuelve |
| `password authentication failed` | Volumen con la contraseña anterior |
| `db` no resuelve | Contenedor fuera de la red `backend` |
| `Connection refused` en `localhost` | `localhost` es el propio contenedor |
| `depends_on` no espera | Falta `condition: service_healthy` |
| Cambios no visibles | Se arrancó sin override o sin watch |

---

# Cierre

Checklist:

- [ ] Escribo un `compose.yaml` con healthchecks y orden real
- [ ] Separo redes y verifico quién ve a quién
- [ ] Uso secretos como archivo, no como variable
- [ ] Distingo `down` de `down -v`
- [ ] Diagnostico DNS y puertos con `getent` y `netshoot`
- [ ] Explico por qué `localhost` no cruza contenedores

**Próxima clase:** orquestación y Kubernetes con `kind`.

<!--
Notas para el instructor:
- No empezar el lab 2b sin haber mostrado el fallo de DNS en vivo.
- Si el aula no tiene salida a Internet, tener netshoot y las imágenes pre-descargadas.
- Guardar 10 minutos para la puesta en común de la guía de diagnóstico.
-->
