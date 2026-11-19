# Guía del docente: clase 2

Guion de sesión para las 4 horas. Los tiempos son relativos al inicio (00:00). La guía del alumno es [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md) y se sigue en paralelo; el instructor comparte pantalla.

## Modalidad virtual

Cada participante ejecuta Docker en su equipo y sigue la guía en paralelo. Las imágenes se descargan antes de la sesión en cada equipo para que la clase no dependa de seis descargas simultáneas. Si alguien pierde la conexión, la guía y los comandos le permiten retomar sin esperar al grupo.

**Material que conviene tener abierto:** [`slides.md`](slides.md), [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md), [`lab/retos-diagnostico.md`](lab/retos-diagnostico.md), [`evaluacion/rubrica-clase-02.md`](evaluacion/rubrica-clase-02.md) y una copia impresa de [`recursos/checklist-compose.md`](recursos/checklist-compose.md) por participante.

## Antes de la clase

### El día anterior

Construir la imagen y dejar el stack probado. La clase empieza con el compose ya funcionando en la máquina del instructor, pero cada alumno lo levanta en la suya:

```bash
cd clase-02/lab
cp secrets/db_password.txt.example secrets/db_password.txt
docker compose build api
docker compose up -d --wait
docker compose ps
curl -s localhost:18010/healthz
```

Descargar las imágenes para no depender de la conexión de cada participante:

```bash
docker pull postgres:16-alpine
docker pull redis:7-alpine
docker pull nginx:1.27-alpine
docker pull adminer:4
docker pull nicolaka/netshoot:latest
```

### Quince minutos antes

- Comprobar que 18010, 18011, 18012 y 18015 están libres: `ss -ltn | grep -E '18010|18011|18012|18015'`.
- Verificar que `secrets/db_password.txt` existe y que `git status` no lo muestra.
- Ejecutar una vez [`demos/01-redes.sh`](demos/01-redes.sh) y [`demos/02-dns-roto.sh`](demos/02-dns-roto.sh) con el stack levantado.
- Probar el reto 3, que es el único que crea un contenedor fuera del proyecto: `docker network ls | grep tienda_frontend`.
- Cada participante trabaja en su equipo, así que los nombres fijos del compose (`tienda`, `tienda_frontend`, `tienda_backend`) no chocan. Solo si dos personas comparten host hay que editar `name`, los nombres de red y los puertos.

## Agenda

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:15 | Repaso de la clase 1 y verificación de entornos | `docker images`, preguntas del lab 1 |
| 00:15-00:55 | Compose: servicios, redes, volúmenes, secretos, orden de arranque y override | `slides.md` |
| 00:55-01:50 | Lab 2a, pasos 0 a 3 | `lab/guia-paso-a-paso.md` |
| 01:50-02:00 | Pausa | |
| 02:00-02:40 | Networking y demos de DNS y aislamiento | `slides.md` + `demos/01-redes.sh` + `demos/02-dns-roto.sh` |
| 02:40-03:25 | Lab 2b, pasos 4 a 6 | `lab/guia-paso-a-paso.md` |
| 03:25-03:50 | Retos de diagnóstico en parejas | `lab/retos-diagnostico.md` |
| 03:50-04:00 | Entregable, dudas y cierre | `evaluacion/rubrica-clase-02.md` |

El paso 7 (override, watch y Adminer) queda como extensión para quien termine antes o como deberes. Se explica en la teoría y el archivo `compose.override.yaml` ya está en el repositorio.

La agenda suma 240 min. Los cuatro retos son parte del plan; el paso 7 es la reserva si el grupo termina antes. Si aun así sobra tiempo, [`lab/lab-2c.md`](lab/lab-2c.md) tiene un laboratorio de 60 min de operación del stack y [`extra-60-min.md`](extra-60-min.md) tres bloques de temas nuevos: DNS, tcpdump y anclas YAML.

## 00:00-00:15. Repaso y entornos

1. Pedir a cada participante una frase sobre la clase anterior: qué comparte un contenedor, qué aísla, qué limita y qué es una capa.
2. Comprobar que todos tienen la imagen de partida:

```bash
docker image inspect tienda-api:optimized >/dev/null && echo "imagen ok"
docker compose version
docker version --format '{{.Server.Version}}'
```

3. Presentar el hilo: la misma API de la clase 1 ahora necesita Postgres, Redis y un proxy. El problema deja de ser construir una imagen y pasa a ser coordinar varios contenedores.
4. No avanzar hasta que los 6 tengan Docker y Compose respondiendo. Los que no tengan la imagen pueden construirla en el paso 2 del laboratorio.

## 00:15-00:55. Compose

Recorrer las diapositivas con preguntas. El orden que importa:

- Qué cuatro secciones tiene un compose y qué describe cada una.
- Por qué la red `bridge` por defecto no resuelve nombres y una red user-defined sí.
- `depends_on` sin `condition` no espera a que el servicio esté listo.
- El secreto se monta como archivo en `/run/secrets`, no viaja en la imagen.
- El override se carga solo cuando no se pasa `-f`; si se pasa `-f`, hay que añadirlo a mano.

Antes de arrancar nada, abrir el compose real del laboratorio y preguntar:

```bash
cd clase-02/lab
docker compose config --services
docker compose config --volumes
```

Preguntas para el grupo: ¿qué servicio publica el puerto 18010?, ¿qué servicios están en `backend`?, ¿por qué la API está en las dos redes y el proxy en una sola?

Checkpoint: los 6 saben que el proxy no puede resolver `db` y que eso es correcto.

## 00:55-01:50. Laboratorio 2a, pasos 0 a 3

Todos trabajan desde `clase-02/lab`. Circular con esta tabla en la mano.

| Hora | Deberían estar en | Señal de que va bien |
|---|---|---|
| 01:05 | Pasos 0 y 1 | `docker compose config --quiet` pasa y hay 4 servicios |
| 01:15 | Paso 2 | Los cuatro contenedores en `healthy`, API después de db y redis |
| 01:30 | Paso 3 | `curl localhost:18010/` responde con `"db":"ok"` y `"redis":"ok"` |
| 01:45 | Paso 3 | `curl localhost:18010/productos` responde y la API está sana |

Puntos donde se traba la gente:

- La API tarda en arrancar porque `init_db` reintenta contra Postgres. Si el healthcheck está en `starting`, esperar; no borrar el contenedor.
- `password authentication failed` casi siempre significa un volumen viejo con otra contraseña. Se arregla en el reto 4 o con `down -v` si no hay datos que conservar.
- `docker compose ps` no muestra Adminer: está detrás del profile `tools` y se levanta con `--profile tools`.
- Si `curl localhost:18010` devuelve 502, revisar primero si la API está sana, no tocar Nginx.

Si a las 01:30 alguien sigue en el paso 2, sentarlo con un compañero y que continúe desde el paso 3 con el stack del compañero. No frenar al grupo.

## 01:50-02:00. Pausa

Aprovechar para comprobar que los 6 tienen el stack sano y el secreto creado. Resolver ahora los puertos ocupados, no durante el laboratorio siguiente.

## 02:00-02:40. Networking y demos

Explicar con el stack en marcha, no en abstracto:

- Qué es una red: subred, bridge y DNS propios; un contenedor solo ve a quien comparte red.
- Separación de servicios: `proxy` en `frontend`; `api` en `frontend` y `backend`; `db` y `redis` solo en `backend`.
- Red por defecto contra red user-defined: la primera no tiene DNS por nombre.
- `internal: true`: los contenedores de `backend` no tienen salida a Internet.
- Publicar un puerto no es un firewall: el puerto del host llega al contenedor aunque la red sea interna, siempre que el contenedor esté también en una red publicable.
- `localhost` dentro de un contenedor es ese contenedor, no el host.

Demo 01:

```bash
cd clase-02/demos
./01-redes.sh
```

Qué señalar: la API resuelve `db` y `redis`; el proxy no resuelve `db`; `localhost:5432` no llega a Postgres; la IP del contenedor cambia si se recrea.

Demo 02:

```bash
./02-dns-roto.sh
```

Qué señalar: `Name or service not known` es DNS; `Connection refused` es un puerto cerrado en un host que sí existe. Son dos fallos distintos y se diagnostican distinto.

Si sobra tiempo, abrir [`demos/03-redes-especiales.md`](demos/03-redes-especiales.md) y explicar `host`, `none` y `macvlan`. La demo de `macvlan` solo se ejecuta en un host Linux conectado por cable; en laptops se explica con la pantalla compartida.

Checkpoint: los 6 distinguen un error de nombre de un error de puerto.

## 02:40-03:25. Laboratorio 2b, pasos 4 a 6

| Hora | Deberían estar en | Señal de que va bien |
|---|---|---|
| 02:50 | Paso 4 | Saben qué contenedores hay en cada red y por qué el proxy no ve `db` |
| 03:05 | Paso 5 | `getent` falla con nombre inexistente y `localhost` da conexión rechazada |
| 03:15 | Paso 6 | Los datos sobreviven a `docker compose down` sin `-v` |
| 03:25 | Paso 6 cerrado | Dejan el stack sano para los retos |

Errores que aparecen aquí:

- Alguien intenta "arreglar" que el proxy no resuelva `db`. Es el comportamiento esperado: el proxy solo debe hablar con la API.
- `down -v` borra el volumen y los productos. Avisar antes de que lo ejecuten.
- `netshoot` sin la red correcta no ve nada. Hay que pasar `--network tienda_backend` o `tienda_frontend`.

Si el grupo va adelantado a las 03:10, hacer el paso 7 en 10 minutos: `docker compose --profile tools up -d`, abrir Adminer y probar `docker compose watch` con un cambio pequeño. Si va justo, el paso 7 se queda como deberes.

## 03:25-03:50. Retos de diagnóstico

Presentar [`lab/retos-diagnostico.md`](lab/retos-diagnostico.md) y trabajar en parejas. Cada pareja hace los cuatro retos en orden; el que no ejecuta lee la salida y decide el siguiente comando.

| Min | Reto | Qué se aprende |
|---|---|---|
| 03:25-03:30 | 1. Proxy 504 | Un upstream que no responde agota el timeout del proxy |
| 03:30-03:37 | 2. Host de base inexistente | DNS contra puerto; el error aparece en `/readyz`, no en el log de arranque |
| 03:37-03:42 | 3. Proxy al puerto equivocado | 502 por rechazo, distinto del 504 por timeout |
| 03:42-03:50 | 4. Secreto viejo | La contraseña de Postgres solo se aplica al inicializar el volumen |

Reglas para el instructor:

- El plan incluye los cuatro retos. Si surge una emergencia de tiempo, el recorte mínimo son los retos 1 y 3; el 2 y el 4 quedan como deberes.
- Los retos 2 y 4 esperan cerca de 70 segundos porque la API reintenta la conexión. Mientras esperan, pedir que escriban el diagnóstico en tres líneas.
- No permitir `down -v` sin avisar de que borra la base. El reto 4 tiene un arreglo que no borra nada.
- Al terminar, verificar que no quedan overlays en `/tmp` ni el contenedor `proxy-roto`.

Checkpoint: cada pareja explica un síntoma, una causa y el comando que lo confirma.

## 03:50-04:00. Entregable y cierre

1. Recordar el entregable: `compose.yaml` que arranca sano, captura de las dos redes y guía de diagnóstico de 10 líneas.
2. Mostrar la rúbrica y el checklist.
3. Cerrar con una pregunta por persona: diferencia entre red por defecto y user-defined, qué hace `service_healthy`, dónde vive el secreto, por qué `localhost` no cruza contenedores, qué diferencia hay entre 502 y 504.
4. Deberes: paso 7 (override, watch y Adminer) y el reto que no se haya hecho.
5. Limpieza opcional, solo si no se reutiliza el stack:

```bash
docker compose --profile tools down
docker network ls | grep tienda || echo "redes limpias"
```

No borrar `lab/app`, `lab/compose.yaml` ni el secreto: la clase 3 reutiliza la aplicación y la clase 4 el Dockerfile endurecido.

## Si algo falla en vivo

| Síntoma | Qué hacer |
|---|---|
| `port is already allocated` | `docker compose down` del proyecto viejo o cambiar el puerto en el compose |
| La API reinicia en bucle | `docker compose logs api`; revisar `depends_on` y el secreto |
| `password authentication failed` | El volumen tiene la contraseña vieja; restaurar el secreto o `down -v` |
| Nginx devuelve 504 | La API está parada o no responde; `docker compose ps` y `start api` |
| Nginx devuelve 502 | La API corre pero no escucha en el puerto configurado; revisar `log` y el upstream |
| `db` no resuelve desde el proxy | Es lo esperado; el proxy solo habla con la API |
| `docker compose config` falla | Error de YAML o variable sin valor; leer la línea que indica |
| Watch no recarga | Se arrancó con `-f` o no está corriendo `docker compose watch` |
| Adminer no abre | Falta `--profile tools` o el puerto 18012 está ocupado |
| El grupo va atrasado | Saltar el paso 7 y hacer solo los retos 1 y 3; el resto queda para casa |

## Después de la clase

- Revisar que las guías de diagnóstico incluyan, junto a las capturas, un síntoma, una causa y el comando que lo confirma.
- Anotar quién quedó atrasado para el repaso de la clase 3.
- Si alguien no hizo el paso 7, recordarlo antes de la clase 4, que reutiliza el endurecimiento del compose.
- Si cambiaste algo del material, actualizar `slides.md` y las capturas de resultados medidos.
