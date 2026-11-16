---
marp: true
theme: default
paginate: true
header: "Docker Avanzado · Clase 4"
style: |
  section { font-size: 22px; }
---

# Docker Avanzado

## Clase 4: seguridad de la imagen y pipeline de CI/CD

4 horas · 6 participantes · `tienda-api` endurecida y automatizada

---

# Contenido

1. Qué superficie de ataque tiene un contenedor
2. Endurecer la imagen y el runtime
3. CVEs, SBOM y gates que no se rompen solos
4. Un pipeline de build, escaneo y publicación
5. Lab: de la imagen de la clase 2 a una con gates

**Hilo del curso:** la app se construyó, se compuso, se orquestó. Hoy se asegura y se automatiza.

---

# Superficie de ataque

```text
                 imagen
        +---------------------+
        | base + paquetes     |
        | dependencias        |
        | código              |
        | usuario y permisos  |
        +---------------------+
                 |
                 v
        runtime del contenedor
        +---------------------+
        | capacidades         |
        | sistema de archivos |
        | red                 |
        | secretos montados   |
        +---------------------+
```

Un control en la imagen define lo que el proceso puede hacer; un control en el runtime limita lo que ese proceso alcanza. Hacen falta los dos.

---

# La imagen es un artefacto

- Se construye una vez y se despliega muchas.
- Se identifica por digest, no por `latest`.
- Se escanea, se firma y se conserva.
- Si no sabes qué lleva, no puedes responder a un CVE.

```bash
docker image inspect tienda-api:4.0 --format '{{.Id}}'
docker image inspect tienda-api:4.0 --format '{{index .RepoDigests 0}}'
```

---

# Endurecer la imagen

```dockerfile
RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 \
       --no-create-home --shell /usr/sbin/nologin app

COPY --chown=10001:10001 app.py .
USER 10001:10001
```

- UID fijo: Kubernetes puede declararlo sin adivinar.
- Sin home ni shell de login: menos comodidad para un atacante.
- `--chown`: el código pertenece al usuario que lo ejecuta.

---

# Menos piezas en runtime

```dockerfile
RUN rm -rf /usr/local/lib/python3.12/site-packages/pip \
           /usr/local/bin/pip /usr/local/bin/pip3
```

El venv ya tiene las dependencias instaladas. pip en runtime solo añade superficie y CVEs.

Lo mismo aplica a compiladores, cabeceras y herramientas de build: se quedan en la etapa `builder`.

---

# Secretos y capas

```dockerfile
# Mal: queda en el historial y en la imagen
ARG DB_PASSWORD
ENV DB_PASSWORD=$DB_PASSWORD
```

```yaml
# Bien: se monta en ejecución
secrets:
  - db_password
```

```yaml
environment:
  DB_PASSWORD_FILE: /run/secrets/db_password
```

Un `ARG` no es secreto. Cualquiera con la imagen puede leer el historial.

---

# Endurecer el runtime

```yaml
user: "10001:10001"
read_only: true
tmpfs:
  - /tmp
cap_drop:
  - ALL
security_opt:
  - no-new-privileges:true
```

- `read_only`: no se puede dejar un binario ni modificar el código.
- `cap_drop: ALL`: sin `CAP_NET_RAW`, sin `CAP_CHOWN`.
- `no-new-privileges`: bloquea la elevación por setuid.
- `tmpfs`: lo mínimo escribible que el proceso necesita.

---

# El endurecimiento tiene costes

```text
Redis con cap_drop: ALL
  -> el entrypoint usa setpriv
  -> setpriv necesita CAP_SETUID
  -> el contenedor reinicia
```

Solución:

```yaml
redis:
  user: "999:1000"
  cap_drop:
    - ALL
```

El endurecimiento tiene costes, así que cada control se prueba con la imagen concreta. Copiar un bloque de seguridad sin entender la imagen rompe el servicio.

---

# Red de mínima exposición

```text
        host :18030
             |
          [ api ]        red edge
             |
          [ api ]        red backend (internal)
           /     \
      [ db ]   [ redis ]
```

- La base y Redis no salen a Internet.
- La API es el único puente.
- Un contenedor solo en una red `internal` no puede publicar puertos.

---

# Base: slim, alpine o distroless

| Base | Ventaja | Coste |
|---|---|---|
| `python:3.12-slim` | Paquetes actualizados, shell para depurar | Más MB y más CVEs de sistema |
| `python:3.12-alpine` | Menos MB | musl, wheels distintos, más fricción |
| `gcr.io/distroless/python3` | Sin shell ni gestor de paquetes | Difícil de depurar, sin `exec` cómodo |

La base adecuada depende del equipo y del diagnóstico que pueda permitirse.

---

# Cadena de suministro

```text
código -> build -> imagen -> registry -> clúster
   |        |         |          |          |
 commit   deps     SBOM      firma      admisión
          lock    escaneo   cosign     digest
```

Cada flecha permite verificar algo; ninguna etapa por separado cubre la cadena.

---

# Qué dice un escaneo

```text
tienda-api:4.0 (debian 13.7)   2 HIGH
  zlib1g  CVE-2026-...  fixed
venv/.../flask-3.0.3          0
venv/.../gunicorn-22.0.0      0
```

Preguntas correctas:

1. ¿El CVE está en la base o en una dependencia?
2. ¿Hay versión corregida?
3. ¿El proceso afectado se usa en runtime?
4. ¿Qué mitigation existe si no hay parche?

Para decidir, mira dónde está el CVE, si hay parche y si el código afectado se usa.

---

# Gates deterministas

```bash
uid=$(docker run --rm --entrypoint python "$IMAGE" \
  -c 'import os; print(os.getuid())')
[ "$uid" -ne 0 ]
[ "$MB" -le "$MAX_MB" ]
```

- Mismo código, mismo resultado.
- No dependen de la base de CVEs del día.
- Bloquean lo que el equipo puede corregir.

El escaneo se publica como informe. Si se convierte en gate, solo con un umbral acordado.

---

# Pipeline por etapas

```text
build -> test -> gates -> scan -> sign -> push -> deploy
          |        |        |       |       |       |
         unit    user/    SARIF   cosign  digest  approval
                 size
```

- Un fallo en `gates` detiene la publicación.
- El escaneo puede ser informativo o bloquear `CRITICAL`.
- La firma y el digest permiten verificar qué se desplegó.
- El despliegue a producción va con aprobación.

---

# GitHub Actions

```yaml
permissions:
  contents: read
  security-events: write

steps:
  - uses: actions/checkout@v4
  - run: docker build -f clase-02/lab/app/Dockerfile.hardened ...
  - run: clase-04/lab/ci/verificar-imagen.sh tienda-api:4.0
  - uses: aquasecurity/trivy-action@0.28.0
    with:
      image-ref: tienda-api:4.0
      format: sarif
      exit-code: "0"
```

El SARIF necesita `security-events: write`. Las credenciales van en `secrets`.

---

# El mismo control en Kubernetes

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  seccompProfile:
    type: RuntimeDefault
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

El overlay de Kustomize aplica esto sobre la API de la clase 3. No hay una segunda copia del stack.

---

# Lab 4a (55 min)

1. Crear el secreto y validar Compose
2. Leer el Dockerfile endurecido y compararlo
3. Construir y comprobar uid, shell y tamaño
4. Levantar el runtime restringido
5. Comprobar solo lectura, capacidades y redes

Guía: `lab/guia-paso-a-paso.md`

---

# Lab 4b (45 min)

1. Ejecutar los gates en verde y en rojo
2. Escanear con Trivy y leer el informe
3. Generar el SBOM
4. Aplicar el overlay en el clúster de la clase 3
5. Leer el workflow de GitHub Actions
6. Entregar evidencias y limpiar

Entregable: stack endurecido + gates + informe + SBOM.

---

# Errores típicos

| Síntoma | Causa |
|---|---|
| Redis reinicia con `setpriv` | `cap_drop: ALL` sin usuario explícito |
| El puerto no aparece | La API solo está en la red interna |
| `Read-only file system` | Falta `tmpfs` en `/tmp` |
| El gate no lee el uid | La imagen no tiene Python |
| Trivy tarda | Primera descarga de la base |
| El SARIF no aparece | Falta `security-events: write` |
| Contraseña en `docker history` | Se pasó como `ARG` |

---

# Cierre del curso

Lo que te llevas:

- [ ] Construyo imágenes pequeñas, reproducibles y sin root
- [ ] Compongo un stack con redes separadas y secretos
- [ ] Despliego y opero en Kubernetes con probes y recursos
- [ ] Endurezco imagen y runtime con controles probados
- [ ] Pongo gates deterministas en un pipeline
- [ ] Leo un escaneo y un SBOM sin alarmarme por el número

**Siguiente paso:** registry privado, firmas con `cosign`, políticas de admisión y GitOps.

<!--
Notas para el instructor:
- El error de Redis con cap_drop es la discusión central: no copiar seguridad sin probar.
- Si no hay Trivy, el paso 5 se explica con la pantalla compartida; el resto del lab no depende de él.
- No convertir el escaneo en un gate estricto durante la clase: el ruido de CVEs distrae del método.
- Guardar 10 minutos para cerrar el curso completo y enlazar con el siguiente nivel.
-->
