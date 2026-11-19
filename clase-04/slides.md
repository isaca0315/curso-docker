---
marp: true
theme: default
paginate: true
header: "Docker Avanzado · Clase 4"
style: |
  section { font-size: 22px; }
---

# Docker Avanzado

## Clase 4: caso de estudio, auditoría de `tienda-api` 4.0

4 horas · 6 participantes · Docker y Compose, sin Kubernetes

---

# El caso

El lanzamiento de `tienda-api` 4.0 está previsto para hoy a las 16:00. El viernes llegó un informe del auditor con cuatro hallazgos.

Trabajas en parejas. Eres el equipo de plataforma. Al final firma un acta: publicar, publicar con excepción o no publicar.

Cada comando de la clase produce una prueba para el acta.

---

# El informe del auditor

| ID | Hallazgo | Bloque |
|---|---|---|
| H1 | Imagen root, con pip en runtime y código de root | Laboratorio A |
| H2 | Sin evidencia de dónde vive la contraseña | Laboratorio A |
| H3 | Runtime sin límites y base y Redis en red exterior | Laboratorio A |
| H4 | `latest`, sin gates, sin SBOM y sin criterio para CVEs | Laboratorio B |

La pregunta de fondo: *¿qué se arregla construyendo y qué se arregla ejecutando?*

---

# Agenda de las 4 horas

| Hora | Bloque |
|---|---|
| 00:00-00:45 | Presentar el caso y repasar superficie de ataque |
| 00:45-01:40 | Laboratorio A: cerrar H1, H2 y H3 |
| 01:50-02:25 | Hallazgo 4: CVEs, SBOM y gates |
| 02:25-03:10 | Laboratorio B: gates, escaneo y acta |
| 03:10-03:45 | Auditoría cruzada en parejas |
| 03:45-04:00 | Acta de salida y cierre del curso |

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

Un control en la imagen define qué puede hacer el proceso. Un control en el runtime limita qué alcanza. Hacen falta los dos.

---

# H1: la imagen es un artefacto

- Se construye una vez y se despliega muchas veces.
- Se identifica por digest, no por `latest`.
- Se escanea, se firma y se conserva.
- Si no sabes qué lleva, no puedes responder a un CVE.

```bash
docker image inspect tienda-api:4.0 --format '{{.Id}}'
docker image inspect tienda-api:4.0 --format '{{.Config.User}} {{.Size}}'
```

---

# H1: construir sin privilegios

```dockerfile
RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 \
       --no-create-home --shell /usr/sbin/nologin app

COPY --chown=10001:10001 app.py .
USER 10001:10001
```

- UID fijo para reproducir el control en ejecución.
- Sin home ni shell de login.
- El código pertenece a quien lo ejecuta.

`sh` existe en la base slim; lo que se quita es el shell de login del usuario.

---

# H1: menos piezas en runtime

```dockerfile
RUN rm -rf /usr/local/lib/python3.12/site-packages/pip \
           /usr/local/bin/pip /usr/local/bin/pip3
```

El venv ya trae las dependencias. pip en runtime añade superficie y CVEs sin aportar al servicio.

Compiladores, cabeceras y herramientas de build se quedan en la etapa `builder`.

**Prueba para el acta:** `docker run --rm --entrypoint python tienda-api:4.0 -c 'import os; print(os.getuid())'`

---

# H2: el secreto no es una capa

```dockerfile
# Mal: queda en el historial y en la configuración
ARG DB_PASSWORD
ENV DB_PASSWORD=$DB_PASSWORD
```

```yaml
# Bien: se monta en ejecución
secrets:
  - db_password
environment:
  DB_PASSWORD_FILE: /run/secrets/db_password
```

Un `ARG` no es secreto. Cualquiera con la imagen puede leer `docker history`.

**Prueba para el acta:** `docker history tienda-api:4.0 | grep -i password` no debe devolver nada.

---

# H3: endurecer el runtime

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

- `read_only`: no se puede dejar un binario ni cambiar el código.
- `cap_drop: ALL`: sin `CAP_NET_RAW`, sin `CAP_CHOWN`.
- `no-new-privileges`: bloquea la elevación por setuid.
- `tmpfs`: lo mínimo escribible que el proceso necesita.

---

# H3: el endurecimiento tiene costes

```text
Redis con cap_drop: ALL
  -> el entrypoint usa setpriv
  -> setpriv necesita CAP_SETUID
  -> el contenedor reinicia
```

```yaml
redis:
  user: "999:1000"
  cap_drop:
    - ALL
```

Copiar un bloque de seguridad sin probar la imagen rompe el servicio. Cada control se justifica.

---

# H3: red de mínima exposición

```text
       host :18030
            |
         [ api ]      red edge
            |
         [ api ]      red backend (internal)
          /     \
     [ db ]   [ redis ]
```

- La base y Redis no salen a Internet.
- La API es el único puente.
- Un contenedor solo en red `internal` no publica puertos.

---

# H4: la cadena de suministro

```text
código -> build -> imagen -> registry -> despliegue
   |        |         |          |          |
 commit   deps      SBOM      firma     digest
          lock    escaneo    cosign   verificación
```

Cada flecha permite comprobar algo. Ninguna etapa por separado cubre toda la cadena.

En esta clase se construye, se escanea y se decide con gates. La firma y el despliegue se explican, no se implementan.

---

# H4: qué dice un escaneo

```text
tienda-api:4.0 (debian)      2 HIGH
  zlib1g    CVE-...         fixed
  venv/flask-3.0.3          0
  venv/gunicorn-22.0.0      0
```

Preguntas correctas:

1. ¿El CVE está en la base o en una dependencia?
2. ¿Hay versión corregida?
3. ¿El proceso afectado se usa en runtime?
4. ¿Qué mitigación existe si no hay parche?

Un número de CVEs no dice si la imagen es segura.

---

# H4: gates deterministas

```bash
uid=$(docker run --rm --entrypoint python "$IMAGE" \
  -c 'import os; print(os.getuid())')
[ "$uid" -ne 0 ]
[ "$MB" -le "$MAX_MB" ]
```

- La misma imagen da siempre el mismo resultado.
- No dependen de la base de CVEs del día.
- Bloquean lo que el equipo puede corregir.

El escaneo se publica como informe. Si se convierte en gate, es con umbral, fecha y responsable.

---

# H4: pipeline por etapas

```text
build -> test -> gates -> scan -> sign -> push -> deploy
          |       |        |       |       |       |
        unit   user/     SARIF   cosign digest approval
               size
```

- Un fallo en `gates` detiene la publicación.
- El escaneo informa o bloquea `CRITICAL` corregible.
- La firma y el digest permiten verificar qué se publicó.
- Trivy sin permisos no sube el SARIF a GitHub.

---

# Laboratorio A: 55 minutos

1. Verificar Docker, Compose y el secreto.
2. Leer el Dockerfile endurecido y compararlo.
3. Construir y comprobar uid, shell y tamaño.
4. Levantar el stack con runtime restringido.
5. Comprobar secretos, capacidades, solo lectura y redes.

Guía: `lab/guia-paso-a-paso.md`, pasos 0 a 3.

**Entrega parcial:** evidencia de H1, H2 y H3.

---

# Laboratorio B: 50 minutos

1. Gates en verde y en dos casos de fallo.
2. Escaneo con Trivy o informe de respaldo.
3. SBOM en CycloneDX.
4. Lectura del workflow de GitHub Actions.
5. Acta de salida con decisión.

Guía: `lab/guia-paso-a-paso.md`, pasos 4 a 6.

**Entrega parcial:** evidencia de H4 y decisión firmada.

---

# Auditoría cruzada: 35 minutos

Cuatro comprobaciones en `lab/retos-auditoria.md`:

1. Secreto en el historial de la imagen.
2. Capacidad de más.
3. `read_only` sin `tmpfs`.
4. Etiqueta móvil en el `FROM`.

Una pareja busca, otra decide si es hallazgo real o ruido. Cada pareja explica un control en 30 segundos.

---

# Errores típicos del caso

| Síntoma | Causa |
|---|---|
| Redis reinicia con `setpriv` | `cap_drop: ALL` sin usuario explícito |
| El puerto 18030 no aparece | La API solo está en la red interna |
| `Read-only file system` | Falta `tmpfs` en `/tmp` |
| El gate no lee el uid | La imagen no tiene Python |
| Trivy tarda | Primera descarga de la base |
| La contraseña aparece en `docker history` | Se pasó como `ARG` o `ENV` |

---

# Acta de salida

`lab/informes/acta-ejemplo.md` → `lab/informes/acta.md`

Cada hallazgo lleva:

- Estado: abierto o cerrado.
- Evidencia: un comando y su salida.
- Acción: qué se cambió y por qué.
- Decisión: publicar, publicar con excepción o no publicar.

La respuesta correcta es la que se sostiene con la evidencia.

---

# Cierre del curso

Lo que te llevas:

- [ ] Construyo imágenes pequeñas, reproducibles y sin root.
- [ ] Compongo un stack con redes separadas y secretos.
- [ ] Endurezco imagen y runtime con controles probados.
- [ ] Pongo gates deterministas en un pipeline.
- [ ] Leo un escaneo y un SBOM sin alarmarme por el número.
- [ ] Firmo una decisión de publicación con evidencia.

**Siguiente paso:** registry privado, firmas con `cosign`, políticas de admisión y GitOps.

---

<!--
Notas para el instructor:
- Leer los cuatro hallazgos en voz alta al empezar y volver a ellos en cada bloque.
- El error de Redis con cap_drop es la discusión central: no copiar seguridad sin probar.
- Si no hay Trivy, abrir lab/informes/README.md; el resto del laboratorio no depende de él.
- No convertir el escaneo en gate estricto: el ruido de CVEs distrae del método.
- Guardar 15 minutos para el acta y el cierre del curso completo.
-->
