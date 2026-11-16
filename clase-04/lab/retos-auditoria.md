# Retos de auditoría: clase 4

Cuatro comprobaciones para encontrar lo que un Dockerfile y un `docker run` dejan a la vista. Se hacen después del lab 4a, con la imagen `tienda-api:4.0` construida.

| Dato | Valor |
|---|---|
| Duración | 30 min |
| Directorio | `clase-04/lab` |
| Requisito | Imagen `tienda-api:4.0` y stack levantado |
| Formato | Parejas: una persona busca, la otra decide si es un hallazgo real |

## Reglas

- Distinguir hallazgo de ruido: no todo lo que aparece en un escaneo es explotable.
- Para cada reto anota: qué se filtró, dónde se ve y cómo se corrige.
- No cambies el `compose.yaml` de la clase. Los retos se hacen con contenedores desechables o con comandos de solo lectura.
- Al terminar, borra las imágenes y contenedores temporales.

## Reto 1. El secreto quedó en la imagen (7 min)

**Síntoma:** una contraseña pasa de `ENV` al historial y a la configuración de la imagen.

```bash
mkdir -p /tmp/auditoria && cd /tmp/auditoria
cat > Dockerfile <<'EOF'
FROM alpine:3.20
ENV DB_PASSWORD=super-secreta
EOF

docker build -q -t auditoria:env .
docker image inspect auditoria:env --format '{{json .Config.Env}}'
docker history --no-trunc auditoria:env | grep DB_PASSWORD
```

**Esperado:** la contraseña aparece en `.Config.Env` y en la línea `ENV DB_PASSWORD=super-secreta` del historial.

**Por qué importa:** cualquiera que pueda descargar la imagen lee la contraseña. Cambiarla en el Dockerfile no borra la capa anterior: queda en el historial de la imagen publicada.

**Arreglo:** el secreto se monta en ejecución, nunca se declara en `ENV` ni en `ARG`. En Compose ya se usa `secrets`; en un build que necesite el valor se usa un secreto de BuildKit:

```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=db_password \
    cat /run/secrets/db_password >/dev/null
```

```bash
docker build --secret id=db_password,src=secrets/db_password.txt .
```

**Comprobación:** repite `docker history` sobre la imagen buena y confirma que no hay contraseñas.

```bash
docker history --no-trunc tienda-api:4.0 | grep -i pass || echo "sin secretos en el historial"
docker image inspect tienda-api:4.0 --format '{{json .Config.Env}}'
```

Vuelve al directorio del laboratorio (el `cd -` regresa al directorio anterior, que era `clase-04/lab`):

```bash
cd -
```

## Reto 2. Una capacidad de más (7 min)

**Síntoma:** un contenedor conserva capacidades que no necesita.

```bash
echo "por defecto"
docker run --rm alpine:3.20 grep CapEff /proc/self/status

echo "sin capacidades"
docker run --rm --cap-drop ALL alpine:3.20 grep CapEff /proc/self/status

echo "con NET_ADMIN"
docker run --rm --cap-add NET_ADMIN alpine:3.20 grep CapEff /proc/self/status
```

**Esperado:** el primero y el tercero muestran un valor distinto de cero (`00000000a80425fb` y `00000000a80435fb` en un Docker típico); con `--cap-drop ALL` el valor es `0000000000000000`.

**Por qué importa:** `NET_ADMIN` permite cambiar interfaces, rutas y reglas dentro del namespace. Un proceso comprometido con esa capacidad puede manipular la red del contenedor. La mayoría de servicios no la necesita.

**Comprobación en el stack de la clase:**

```bash
docker compose exec -T api grep CapEff /proc/self/status
docker compose config | grep -A1 cap_drop
```

**Esperado:** `CapEff: 0000000000000000` y, por cada servicio, un bloque `cap_drop:` seguido de `- ALL`. También aparece en `redis`.

**Arreglo:** `cap_drop: [ALL]` y añadir solo la capacidad imprescindible. Redis necesitó `user: "999:1000"` para no depender de `CAP_SETUID`; ese es el ejemplo de que un control tiene un coste y hay que entenderlo.

## Reto 3. El sistema de archivos de solo lectura (8 min)

**Síntoma:** un contenedor endurecido no arranca porque algo escribe en `/tmp`.

```bash
echo "sin tmpfs"
docker run --rm --read-only alpine:3.20 sh -c 'touch /tmp/x' || true

echo "con tmpfs"
docker run --rm --read-only --tmpfs /tmp alpine:3.20 sh -c 'touch /tmp/x && echo ok'
```

**Esperado:** el primero falla con `Read-only file system`; el segundo imprime `ok`.

**Comprobación en la API:**

```bash
docker compose exec -T api sh -c 'touch /app/x' || echo "/app protegido"
docker compose exec -T api sh -c 'touch /tmp/x && echo "/tmp escribible"'
docker compose exec -T api grep NoNewPrivs /proc/self/status
```

**Esperado:** `/app` rechaza la escritura, `/tmp` la acepta y `NoNewPrivs` vale `1`.

**Por qué importa:** `read_only: true` impide que un proceso comprometido deje un binario o un script en el sistema de archivos. `tmpfs` le da un directorio temporal que desaparece al reiniciar. Sin `tmpfs`, Gunicorn y Python pueden fallar al arrancar aunque la imagen sea correcta.

**Arreglo:** declarar solo los directorios temporales que el proceso necesita. Si aparece un `Read-only file system` nuevo, identificar la ruta antes de montar medio sistema de archivos.

## Reto 4. La etiqueta que se mueve (8 min)

**Síntoma:** dos builds del mismo Dockerfile pueden producir imágenes distintas.

```bash
grep -nE '^FROM' ../../clase-02/lab/app/Dockerfile.hardened
docker buildx imagetools inspect python:3.12-slim | head -8
```

**Esperado:** el Dockerfile usa `python:3.12-slim` sin digest. `imagetools` muestra el digest actual y las plataformas:

```text
Digest: sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b
```

**Por qué importa:** `python:3.12-slim` es una etiqueta móvil. Cuando la imagen base se reconstruye, el mismo Dockerfile genera una imagen distinta. Para reproducibilidad y para saber qué se escaneó, se fija el digest:

```dockerfile
FROM python:3.12-slim@sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b AS builder
```

**Matiz:** fijar el digest congela también los parches de seguridad. Hay que actualizarlo de forma periódica y volver a pasar los gates. No es "configurar y olvidar".

**Comprobación:** la imagen final no lleva secretos y declara su base.

```bash
docker image inspect tienda-api:4.0 \
  --format '{{index .Config.Labels "org.opencontainers.image.base.name"}}'
docker image inspect tienda-api:4.0 --format '{{json .Config.Env}}' | grep -i pass \
  || echo "sin contraseñas en el entorno"
```

**Esperado:** la etiqueta `docker.io/library/python:3.12-slim` y ningún `DB_PASSWORD`.

## Cierre

Cada pareja elige un hallazgo y lo cuenta en 30 segundos: qué se filtró, dónde se ve y qué control lo evita. El resto del grupo decide si es crítico, medio o cosmético.

## Limpieza

```bash
rm -rf /tmp/auditoria
docker rmi auditoria:env 2>/dev/null || true
docker compose ps
```

## Checklist de cierre

- [ ] Sé buscar secretos en `docker history` y en `.Config.Env`.
- [ ] Sé leer `CapEff` y explicar por qué `ALL` es el punto de partida.
- [ ] Sé qué rompe un `read_only` sin `tmpfs` y cómo se arregla sin abrir todo el sistema.
- [ ] Sé por qué una etiqueta móvil no identifica lo que se desplegó.
- [ ] Distingo un hallazgo real de un aviso que no aplica a este servicio.
