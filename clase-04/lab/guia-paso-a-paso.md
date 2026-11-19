# Guía paso a paso: caso de estudio, auditoría de `tienda-api` 4.0

| Dato | Valor |
|---|---|
| Duración | 4 h de clase; 105 min de laboratorio (55 min lab A + 50 min lab B) |
| Directorio de trabajo | `clase-04/lab` |
| Imagen | `tienda-api:4.0` (se construye en el paso 2) |
| Disco libre recomendado | 2 GB |
| Entregable | Acta de salida + stack endurecido + salida de los gates + informe de Trivy y SBOM |

## El encargo

El equipo va a publicar la versión 4.0 de la API de la tienda. Un auditor externo entregó este informe el viernes:

| ID | Hallazgo |
|---|---|
| H1 | La imagen corre como root, conserva pip en runtime y el código pertenece a root |
| H2 | No hay evidencia de dónde vive la contraseña ni de que quede fuera del historial de la imagen |
| H3 | El runtime no limita capacidades ni escritura, y la base y Redis comparten red con el exterior |
| H4 | El pipeline publica por `latest`, sin gates, sin SBOM y sin criterio para interpretar CVEs |

Trabajas en parejas. Cada hallazgo se cierra con un comando que puedas mostrar al instructor. Al final firmas un acta con la decisión de publicar o no publicar.

## Qué vas a aprender

1. Distinguir lo que se corrige en la imagen de lo que se corrige en el runtime.
2. Construir una imagen que arranca sin privilegios, sin shell de login y sin pip.
3. Ejecutar un contenedor con sistema de archivos de solo lectura y capacidades cero.
4. Mantener la contraseña fuera de las capas de la imagen.
5. Poner gates deterministas y usar el escaneo como informe.
6. Generar un SBOM y decidir qué CVEs se arreglan con un rebuild.

Esta clase usa Docker y Compose. El clúster de la clase 3 no hace falta.

## Mapa de pasos

| Paso | Hallazgo | Qué haces | Tiempo |
|---|---|---|---|
| 0 | Preparación | Verificar el entorno y crear el secreto | 5 min |
| 1 | H1 | Leer el Dockerfile endurecido y compararlo | 10 min |
| 2 | H1 | Construir y comprobar identidad, shell y tamaño | 10 min |
| 3 | H2, H3 | Endurecer el runtime con Compose | 30 min |
| 4 | H4 | Ejecutar los gates de CI | 15 min |
| 5 | H4 | Escanear con Trivy y generar el SBOM | 20 min |
| 6 | Cierre | Leer el pipeline de GitHub Actions y firmar el acta | 15 min |

## Convenciones

- Todos los comandos se ejecutan desde `clase-04/lab`.
- La API publica el puerto 18030. No hay proxy en esta clase.
- `backend` es interna. La API se conecta también a `edge` para poder publicar el puerto.
- Los comandos están en bash. En Windows, usa WSL2 o Git Bash.
- Docker Desktop ejecuta lo mismo. La pestaña Containers muestra el proyecto `tienda-segura`; el botón de logs equivale a `docker compose logs`.

## Paso 0. Verificar el entorno y crear el secreto

**Hallazgo:** preparación para H2.
**Objetivo:** confirmar que Docker y Compose funcionan y preparar la contraseña fuera del repositorio.

```bash
docker version --format 'cliente {{.Client.Version}} / servidor {{.Server.Version}}'
docker compose version
docker run --rm hello-world
```

**Esperado:** cliente y servidor responden, Compose v2.24 o superior y el mensaje `Hello from Docker!`.

Crea el secreto:

```bash
cp secrets/db_password.txt.example secrets/db_password.txt
```

`secrets/db_password.txt` está en `.gitignore`. Compose lo monta en `/run/secrets/db_password`.

Trivy es opcional. El laboratorio funciona sin él; el paso 5 lo explica.

```bash
trivy --version || echo "Trivy no instalado: el escaneo queda como lectura"
```

**Checkpoint:**

- [ ] `docker compose version` responde.
- [ ] `secrets/db_password.txt` existe.
- [ ] `git status` no muestra ese archivo.

## Paso 1. Leer el Dockerfile endurecido y compararlo

**Hallazgo H1:** la imagen corre como root y conserva herramientas innecesarias.
**Objetivo:** entender cada cambio frente a la imagen de la clase 2 antes de construir.

El Dockerfile vive junto a la aplicación, en `clase-02/lab/app/Dockerfile.hardened`. Compáralo con el de la clase 2:

```bash
diff -u ../../clase-02/lab/app/Dockerfile ../../clase-02/lab/app/Dockerfile.hardened
```

| Cambio | Hallazgo que cierra | Por qué |
|---|---|---|
| `groupadd` y `useradd` con UID y GID 10001 | H1 | Fija el usuario que ejecuta el proceso |
| `--no-create-home` y `--shell /usr/sbin/nologin` | H1 | No se crea el directorio home y el usuario no tiene shell de login |
| `rm -rf` de pip en runtime | H1 | El venv ya tiene las dependencias; pip solo amplía la superficie |
| `COPY --chown=10001:10001` | H1 | El código pertenece al usuario que lo ejecuta, no a root |
| Etiquetas OCI | H4 | El artefacto se puede identificar y rastrear por versión |
| `PYTHONDONTWRITEBYTECODE=1` | H3 | Python no intenta escribir `__pycache__` en un sistema de solo lectura |
| `HEALTHCHECK` con `start-period` | H1 | La imagen tarda menos en marcar el arranque como fallido |
| `--access-logfile -` | H3 | Los accesos van a stdout, no a un archivo dentro del contenedor |

La imagen base sigue siendo `python:3.12-slim`. Una imagen distroless quitaría el shell y el gestor de paquetes, pero complica el diagnóstico y no elimina los CVEs de la base. Cambiar el `FROM` es una rama opcional del ejercicio.

**Checkpoint:**

- [ ] Sabes qué usuario ejecuta el proceso y desde qué línea del Dockerfile.
- [ ] Sabes por qué se borra pip del runtime.
- [ ] Sabes por qué el código se copia con `--chown`.

## Paso 2. Construir y comprobar identidad, shell y tamaño

**Hallazgo H1:** cerrar la imagen con privilegios.
**Objetivo:** verificar en la imagen las decisiones del Dockerfile.

```bash
docker compose build api
docker image inspect tienda-api:4.0 --format 'user={{.Config.User}} size={{.Size}}'
docker run --rm --entrypoint python tienda-api:4.0 -c 'import os; print("uid", os.getuid(), "gid", os.getgid())'
docker run --rm --entrypoint sh tienda-api:4.0 -c 'id; command -v pip || echo "pip no está"; command -v gunicorn'
```

**Esperado:**

```text
user=10001:10001 size=201615652
uid 10001 gid 10001
uid=10001(app) gid=10001(app) groups=10001(app)
pip no está
/venv/bin/gunicorn
```

El tamaño ronda los 192 MiB. La imagen de la clase 2 medía cerca de 220 MB porque conservaba pip y setuptools en el venv. La ganancia de tamaño es pequeña; lo que baja es la superficie que queda en runtime.

Comprueba que el shell de login no existe:

```bash
docker run --rm --entrypoint sh tienda-api:4.0 -c 'getent passwd app'
```

**Esperado:** la línea termina en `/usr/sbin/nologin`. El campo home aparece como `/home/app`, pero el directorio no existe porque `useradd` se llamó con `--no-create-home`. Puedes comprobarlo con `ls -ld /home/app`. `sh` sigue existiendo en la imagen, porque `python:3.12-slim` lo incluye; el usuario no lo tiene como shell. Para quitar también `sh` hace falta una base distroless y renunciar al `exec` interactivo.

**Evidencia para el acta:** copia la salida de `docker image inspect` y de `docker run --entrypoint python`.

**Checkpoint:**

- [ ] La imagen declara `10001:10001`.
- [ ] El proceso arranca con uid 10001.
- [ ] pip no está en el runtime.
- [ ] El usuario no tiene shell de login.

## Paso 3. Endurecer el runtime y sacar el secreto de la imagen

**Hallazgos H2 y H3:** contraseña sin rastro y runtime abierto.
**Objetivo:** aplicar en ejecución lo que la imagen no puede garantizar por sí sola.

Abre `compose.yaml` y localiza estas claves en el servicio `api`:

| Clave | Hallazgo | Efecto |
|---|---|---|
| `user: "10001:10001"` | H1 | Refuerza el usuario de la imagen |
| `read_only: true` | H3 | El sistema de archivos raíz no se puede escribir |
| `tmpfs: ["/tmp"]` | H3 | Gunicorn y Python tienen un directorio temporal escribible |
| `cap_drop: [ALL]` | H3 | El proceso no conserva ninguna capacidad |
| `security_opt: no-new-privileges:true` | H3 | Un binario con setuid no puede elevar privilegios |
| `mem_limit` y `cpus` | H3 | Un fallo o un bucle no consume todo el host |
| `internal: true` en `backend` | H3 | Postgres y Redis no salen a Internet |
| `secrets` y `DB_PASSWORD_FILE` | H2 | La contraseña se monta como archivo en ejecución |

Antes de arrancar, comprueba el historial de la imagen:

```bash
docker history tienda-api:4.0 --no-trunc | grep -i -E 'password|secreta' || echo "sin secretos en el historial"
```

Arranca el stack:

```bash
docker compose up -d
docker compose ps
curl -s localhost:18030/
curl -s localhost:18030/productos
```

**Esperado:** los tres servicios en `healthy` y la API con `"version":"4.0"`.

Ahora comprueba el endurecimiento desde dentro:

```bash
docker compose exec -T api id
docker compose exec -T api sh -c 'touch /app/prueba' || true
docker compose exec -T api sh -c 'touch /tmp/prueba && echo "tmp escribible"'
docker compose exec -T api sh -c 'grep -E "Cap(Eff|Bnd)" /proc/self/status'
docker inspect tienda-segura-api-1 --format 'readonly={{.HostConfig.ReadonlyRootfs}} capdrop={{.HostConfig.CapDrop}} secopt={{.HostConfig.SecurityOpt}}'
```

**Esperado:**

```text
uid=10001(app) gid=10001(app)
touch: cannot touch '/app/prueba': Read-only file system
tmp escribible
CapEff:	0000000000000000
CapBnd:	0000000000000000
readonly=true capdrop=[ALL] secopt=[no-new-privileges:true]
```

Mira las redes:

```bash
docker network inspect tienda_segura_backend --format 'backend: {{range .Containers}}{{.Name}} {{end}}'
docker network inspect tienda_segura_edge --format 'edge:    {{range .Containers}}{{.Name}} {{end}}'
```

**Esperado:** `backend` contiene `db`, `redis` y `api`; `edge` solo `api`.

La API necesita `edge` porque un contenedor conectado solo a una red `internal` no recibe mapeo de puertos. Es el mismo detalle que apareció con Adminer en la clase 2. Como contrapartida, `edge` da salida a Internet a la API; si no la necesita, se restringe en el host.

Aquí aparece el detalle que decide si el hallazgo H3 queda cerrado. Redis lleva `user: "999:1000"`: su entrypoint usa `setpriv` para bajar de root a redis y `cap_drop: ALL` quita `CAP_SETUID`. Si quitas esa línea, Redis reinicia con `setpriv: setresuid failed`. La corrección es declarar el usuario, no devolver la capacidad. Postgres se deja sin `cap_drop` porque su entrypoint necesita `gosu` para inicializar el volumen.

**Evidencia para el acta:** copia la salida de `docker history` (H2), de `grep Cap` y de los dos `docker network inspect` (H3).

**Checkpoint:**

- [ ] `docker history` no muestra la contraseña.
- [ ] La API responde en el puerto 18030.
- [ ] `/app` es de solo lectura y `/tmp` no.
- [ ] Las capacidades efectivas son cero.
- [ ] La base y Redis no están en la red `edge`.
- [ ] Sabes por qué Redis necesita un usuario explícito.

## Paso 4. Ejecutar los gates de CI

**Hallazgo H4:** el pipeline publica sin control.
**Objetivo:** comprobar la imagen con reglas que no dependen del día ni de la base de CVEs.

```bash
./ci/verificar-imagen.sh tienda-api:4.0
```

**Esperado:**

```text
== Gates de tienda-api:4.0 ==
  OK    el proceso arranca con uid=10001
  OK    Config.User=10001:10001
  OK    tamaño 192 MiB (máximo 300 MiB)
  INFO  Trivy en modo informe (sin bloquear). Activa el gate con TRIVY_GATE=1

Resultado: imagen apta
```

El script hace tres comprobaciones que siempre dan el mismo resultado para la misma imagen:

1. Arranca un contenedor y lee `os.getuid()`.
2. Lee `Config.User` de la imagen.
3. Compara el tamaño con `MAX_MB`.

Prueba los dos fallos. Si la imagen base no está en local, descárgala primero: el build con BuildKit no siempre deja la base etiquetada en el equipo.

```bash
docker pull python:3.12-slim
./ci/verificar-imagen.sh python:3.12-slim || true
MAX_MB=50 ./ci/verificar-imagen.sh tienda-api:4.0 || true
```

**Esperado:** la imagen base falla por usuario root y el límite bajo falla por tamaño. El pipeline se detiene antes de publicar.

Trivy no bloquea por defecto. Si quieres convertirlo en gate:

```bash
TRIVY_GATE=1 ./ci/verificar-imagen.sh tienda-api:4.0 || true
```

Solo falla con CVEs `CRITICAL` que tengan corrección. Un CVE nuevo en Debian no debería romper un pipeline que no cambió. La decisión de qué hacer con un `HIGH` es del equipo, con fecha y responsable.

**Checkpoint:**

- [ ] El gate pasa con la imagen endurecida.
- [ ] El gate falla con `python:3.12-slim`.
- [ ] El gate falla con un límite de tamaño bajo.
- [ ] Entiendes por qué el escaneo no es el gate principal.

## Paso 5. Escanear con Trivy y generar el SBOM

**Hallazgo H4:** no hay criterio para interpretar CVEs ni inventario de la imagen.
**Objetivo:** leer el informe sin confundir "hay un CVE" con "la imagen es insegura".

```bash
trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed tienda-api:4.0
```

**Esperado en la fecha del curso:** 0 `CRITICAL` y 2 `HIGH` en `zlib1g`, ambos con versión corregida en la base Debian. La lista cambia con el tiempo; revisa qué parte del stack afecta cada aviso y si existe parche.

Genera el SBOM:

```bash
trivy image --format cyclonedx --output /tmp/tienda-api-sbom.json tienda-api:4.0
du -h /tmp/tienda-api-sbom.json
```

**Esperado:** un archivo de unos 200 KB con todas las dependencias y sus versiones.

Interpreta el resultado por capas:

- Un CVE en `debian` se corrige actualizando la imagen base o reconstruyendo cuando el repositorio publica el parche.
- Un CVE en `python-pkg` se corrige subiendo la versión en `requirements.txt`.
- Un CVE `unfixed` no se arregla con un rebuild. Se mitiga con el runtime endurecido, con red restringida o aceptando el riesgo por escrito.
- El SBOM sirve para responder "¿qué lleva esta imagen?" sin volver a escanear.

Si Trivy no está instalado, instálalo desde <https://trivy.dev> o abre el informe guardado en [`informes/README.md`](informes/README.md). El resto de la clase no depende de él.

**Checkpoint:**

- [ ] Viste el número de CVEs por severidad.
- [ ] Distingues un CVE de la base de uno de Python.
- [ ] Generaste el SBOM.
- [ ] Sabes qué CVE no se arregla con un rebuild.

## Paso 6. Leer el pipeline y firmar el acta de salida

**Hallazgo H4:** publicar por `latest` sin gates ni aprobación.
**Objetivo:** entender el orden de un pipeline real y dejar la decisión por escrito.

Abre `ci/github-actions-ci.yml` y sigue las etapas:

| Etapa | Qué hace | Qué la puede romper |
|---|---|---|
| checkout | Trae el repositorio | Rama o permisos |
| build | Construye `tienda-api:4.0` | Dockerfile o dependencias |
| gates | Ejecuta `verificar-imagen.sh` | Usuario root o tamaño |
| Trivy | Genera SARIF para Code Scanning | Base de datos o red |
| upload-sarif | Publica el informe | Falta `security-events: write` |
| push | Publica en el registry (comentado) | Credenciales |

El workflow no está activo en el repositorio del curso: vive en `lab/ci/` como ejemplo. No lo copies a `.github/workflows/` aquí. Para usarlo en otro proyecto, cópialo allí y ajusta las rutas.

Puedes simular las dos etapas importantes en local:

```bash
docker build -f ../../clase-02/lab/app/Dockerfile.hardened -t tienda-api:4.0 ../../clase-02/lab/app
./ci/verificar-imagen.sh tienda-api:4.0
```

Notas para un pipeline real:

- Las credenciales van en `secrets`, nunca en `env` del workflow ni en la imagen.
- La imagen se publica con etiqueta de versión y digest, no con `latest` a secas.
- Un despliegue a producción va después de los gates y con aprobación manual.
- Si el pipeline firma imágenes con `cosign`, la verificación ocurre en el clúster, no en el runner.

### Acta de salida

Copia [`informes/acta-ejemplo.md`](informes/acta-ejemplo.md) a `informes/acta.md` y rellénala con tus salidas reales. La decisión puede ser publicar, publicar con excepción documentada o no publicar. Lo que se evalúa es que cada respuesta tenga evidencia.

**Checkpoint:**

- [ ] Sabes qué etapa bloquea la publicación.
- [ ] Sabes qué permiso necesita el SARIF.
- [ ] Sabes dónde van las credenciales del registry.
- [ ] Entiendes por qué `latest` no es una versión.
- [ ] El acta tiene una decisión y evidencia para los cuatro hallazgos.

## Entregable y limpieza

Entrega:

1. `informes/acta.md` con la decisión y la evidencia de los cuatro hallazgos.
2. El stack levantado con `docker compose ps` mostrando los tres servicios sanos.
3. La salida de `./ci/verificar-imagen.sh tienda-api:4.0` y de los dos casos de fallo.
4. El informe de Trivy y el SBOM generado.
5. Una frase que explique por qué el gate de tamaño no depende de la base de CVEs.
6. Una frase que explique qué cambia entre el Dockerfile de la clase 2 y el endurecido.

Demo oral de 3 minutos: explicar un control de imagen, uno de runtime y por qué el gate no es el escaneo.

Limpieza:

```bash
docker compose down
docker compose down -v
docker rmi tienda-api:4.0 2>/dev/null || true
```

Rúbrica: [`../evaluacion/rubrica-clase-04.md`](../evaluacion/rubrica-clase-04.md).

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| Redis reinicia con `setpriv: setresuid failed` | `cap_drop: ALL` quita `CAP_SETUID` y el entrypoint intenta cambiar de usuario | Declara `user: "999:1000"` en Redis |
| El puerto 18030 no aparece | La API solo está en una red `internal` | Añádela también a `edge` |
| `Read-only file system` al arrancar | Gunicorn o Python escriben en `/app` o `/tmp` | Monta `tmpfs` en `/tmp` y desactiva `__pycache__` |
| `docker run` con uid 0 | La imagen no declara `USER` | Revisa el Dockerfile y `Config.User` |
| El gate dice que no puede comprobar el uid | La imagen no tiene Python o cambió el entrypoint | Ajusta el comando del gate a la imagen |
| Trivy tarda mucho | Está descargando la base de datos | Espera la primera ejecución; después usa caché |
| Trivy devuelve 429 | Límite de descargas | Usa un mirror, ejecútalo en el runner o lee el informe guardado |
| La contraseña aparece en `docker history` | Se pasó como `ARG` o `ENV` | Montar el secreto en ejecución |
| El SARIF no aparece en GitHub | Falta `security-events: write` | Añadir el permiso al workflow |

## Apéndice A. Chuleta de comandos

```bash
# Construcción e imagen
docker compose build api
docker image inspect tienda-api:4.0 --format 'user={{.Config.User}} size={{.Size}}'
docker history tienda-api:4.0

# Secretos y runtime
docker history tienda-api:4.0 | grep -i password || echo "sin secretos"
docker compose up -d
docker compose ps
docker compose exec -T api id
docker compose exec -T api sh -c 'grep Cap /proc/self/status'
docker inspect tienda-segura-api-1 --format '{{json .HostConfig}}'
docker network inspect tienda_segura_backend --format '{{range .Containers}}{{.Name}} {{end}}'

# Gates
./ci/verificar-imagen.sh tienda-api:4.0
./ci/verificar-imagen.sh python:3.12-slim || true
MAX_MB=50 ./ci/verificar-imagen.sh tienda-api:4.0 || true
TRIVY_GATE=1 ./ci/verificar-imagen.sh tienda-api:4.0 || true

# Escaneo
trivy image --severity HIGH,CRITICAL --ignore-unfixed tienda-api:4.0
trivy image --format cyclonedx --output /tmp/tienda-api-sbom.json tienda-api:4.0
```

## Apéndice B. Resultados medidos

| Comprobación | Resultado |
|---|---|
| Tamaño | 192 MiB (201 615 652 bytes) |
| Usuario de la imagen | `10001:10001` |
| uid en ejecución | 10001 |
| pip en runtime | no |
| Contraseña en `docker history` | no |
| `/app` | solo lectura |
| `/tmp` | tmpfs escribible |
| Capacidades efectivas | `0000000000000000` |
| `no-new-privileges` | activo |
| Red `backend` | db, redis, api |
| Red `edge` | api |
| Gates | usuario y tamaño en verde; dos casos en rojo |
| Trivy (fecha del curso) | 0 CRITICAL, 2 HIGH en `zlib1g` |
| SBOM | CycloneDX, unos 200 KB |

Los números de CVEs y los tamaños cambian con las imágenes base. Lo que no cambia es el método: medir, comparar y dejar el gate en lo que controlas.

## Apéndice C. Por qué estos controles

- **Usuario sin privilegios.** Un fallo en la aplicación no empieza con root. El UID fijo permite declararlo en Kubernetes si un día se usa.
- **Sistema de solo lectura.** Un proceso comprometido no puede dejar un binario ni modificar el código. `/tmp` sigue disponible para lo que el runtime necesita.
- **`cap_drop: ALL`.** Un contenedor no necesita `CAP_NET_RAW` ni `CAP_CHOWN` para servir HTTP. Si un día necesita una capacidad, se añade una y se justifica.
- **`no-new-privileges`.** Bloquea la elevación por binarios con setuid, aunque estén en la imagen.
- **Secretos como archivo.** La contraseña no queda en una capa ni en `docker history`. Se monta en ejecución desde un archivo fuera del repositorio.
- **Gates deterministas.** El pipeline falla por algo que el equipo cambió: usuario root o imagen que engordó. No falla porque el mundo publicó un CVE mientras dormías.
- **Trivy como informe.** Sirve para decidir y priorizar. Convertirlo en un gate estricto sin política de excepciones enseña al equipo a ignorar el rojo.
- **SBOM.** Responde qué lleva la imagen cuando aparece un CVE nuevo, sin reconstruirla para mirar dentro.
