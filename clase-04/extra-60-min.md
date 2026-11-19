# Clase 4: hora extra

Material de reserva para cuando el grupo termina antes de las 4 horas. Tres bloques de 20 minutos, independientes. Con 20 minutos, haz el bloque 1; con 40, el 1 y el 2.

La imagen `tienda-api:4.0` tiene que estar construida y el stack de `clase-04/lab` probado al menos una vez.

## Bloque 1. Trivy a fondo (20 min)

**Qué se explica:** separar el ruido de los CVEs accionables y convertir el escaneo en un gate.

Escaneo con severidad y sin parches disponibles:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity HIGH,CRITICAL --ignore-unfixed \
  tienda-api:4.0
```

**Esperado:** una tabla con pocos hallazgos o ninguna, y la base de datos actualizada al día.

Genera el JSON y cuenta:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --format json -o /tmp/trivy.json tienda-api:4.0
python3 - <<'PY'
import json
d = json.load(open("/tmp/trivy.json"))
total = sum(len(r.get("Vulnerabilities") or []) for r in d.get("Results", []))
print("vulnerabilidades:", total)
PY
```

Genera el SBOM y cuenta componentes:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --format cyclonedx -o /tmp/sbom.json tienda-api:4.0
python3 -c 'import json;print("componentes:",len(json.load(open("/tmp/sbom.json"))["components"]))'
```

Convierte el escaneo en gate:

```bash
TRIVY_GATE=1 ./ci/verificar-imagen.sh tienda-api:4.0; echo "exit $?"
```

**Esperado:** el script sale con código distinto de cero si hay CVEs que cumplen el umbral. Ese código es lo que detiene el pipeline.

Si no hay red, usa los informes de `lab/informes/`. Sin ellos, explica la diferencia entre informe y gate con la salida guardada de otra sesión.

**Checkpoint:** el alumno distingue un informe de un gate y sabe qué severidad bloquea.

## Bloque 2. Endurecer el runtime a mano (20 min)

**Qué se explica:** las mismas opciones que aplica el compose, una por una, para ver qué hace cada una.

Arranca la imagen con todo aplicado:

```bash
docker run -d --name tienda-segura \
  --read-only --tmpfs /tmp:rw,noexec,nosuid,size=32m \
  --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 100 --memory 256m \
  tienda-api:4.0
```

Lee la configuración efectiva:

```bash
docker inspect --format 'readonly={{.HostConfig.ReadonlyRootfs}} caps={{.HostConfig.CapDrop}} nnp={{.HostConfig.SecurityOpt}} pids={{.HostConfig.PidsLimit}}' tienda-segura
```

Comprueba los límites desde dentro:

```bash
docker exec tienda-segura python -c 'open("/app/x","w")' || echo "raiz de solo lectura"
docker exec tienda-segura python -c 'open("/tmp/x","w").write("ok"); print("tmp escribible")'
docker exec tienda-segura python -c 'import os; print("uid", os.getuid())'
```

**Esperado:** `/app` falla con `Read-only file system`; `/tmp` funciona; el uid es 10001.

Ahora compara lo que ve Docker cuando se añade una capacidad:

```bash
docker run -d --name con-net-raw --cap-add NET_RAW tienda-api:4.0
docker inspect --format '{{.HostConfig.CapAdd}}' con-net-raw
docker rm -f con-net-raw
```

**Esperado:** `[NET_RAW]`. La app no la necesita; se añade solo si un diagnóstico concreto lo pide. `--cap-drop ALL` deja la lista vacía y el contenedor sigue arrancando.

Limpia:

```bash
docker rm -f tienda-segura
```

**Checkpoint:** el alumno nombra tres flags y el riesgo que cubre cada uno.

## Bloque 3. Secretos de build y digest (20 min)

**Qué se explica:** un secreto no debe quedar en una capa, y una etiqueta no identifica una imagen para siempre.

Crea un secreto y un Dockerfile mínimo:

```bash
mkdir -p /tmp/build-secret
printf 'token-demo\n' > /tmp/build-secret/token
cat > /tmp/Dockerfile.secret <<'EOF'
FROM busybox:1.36
RUN --mount=type=secret,id=token test -s /run/secrets/token
RUN echo listo
EOF
```

Construye con BuildKit y comprueba el historial:

```bash
DOCKER_BUILDKIT=1 docker build \
  --secret id=token,src=/tmp/build-secret/token \
  -f /tmp/Dockerfile.secret -t demo-secret /tmp
docker history --no-trunc demo-secret | grep -i 'token-demo' || echo "sin el valor en el historial"
```

**Esperado:** el historial muestra la ruta `/run/secrets/token`, no el valor. BuildKit enmascara el contenido y no lo deja en ninguna capa.

Comprueba que tampoco existe en runtime:

```bash
docker run --rm demo-secret sh -c 'ls /run/secrets 2>/dev/null || echo "sin secretos en runtime"'
```

Ahora el digest. Una etiqueta puede apuntar a otra imagen mañana; un digest no:

```bash
docker pull nginx:1.27-alpine
docker inspect --format '{{index .RepoDigests 0}}' nginx:1.27-alpine
```

**Esperado:** una referencia `nginx@sha256:...`. En el compose o en el pipeline se fija esa referencia y la imagen deja de moverse.

Limpia:

```bash
docker rmi demo-secret
rm -rf /tmp/build-secret /tmp/Dockerfile.secret
```

**Checkpoint:** el alumno explica por qué `--build-arg` con una contraseña no es una buena idea y qué cambia con un digest.

## Si solo hay 20 minutos

Bloque 1. Si no hay red ni informes guardados, bloque 2, que no descarga nada.

## Si hay 40 minutos

Bloques 1 y 2. El 3 se puede mandar como deberes.
