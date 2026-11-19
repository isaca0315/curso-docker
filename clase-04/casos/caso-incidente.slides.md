---
marp: true
theme: default
paginate: true
header: "Docker Avanzado · Clase 4 · Caso 2"
style: |
  section { font-size: 22px; }
---

# Caso 2: incidente en staging

## Archivo inesperado en `/app`

4 horas · 6 participantes · Docker y Compose

---

# El hecho

Lunes, 07:40. Staging levantó una alerta: apareció `/app/.cache/parche.sh`.

Nadie desplegó ese archivo. El ingeniero de guardia paró el contenedor y conservó el volumen de Postgres.

La versión final debe salir a las 16:00. La pareja decide si se publica.

---

# Línea de tiempo

| Hora | Hecho |
|---|---|
| 22:10 | Staging recibe `tienda-api:latest` |
| 07:35 | Aparece el archivo inesperado |
| 07:40 | Se para el contenedor |
| 08:00 | Se conservan imagen, contenedor y volumen |

Pregunta: ¿qué pasó entre las 22:10 y las 07:35?

---

# Hallazgos iniciales

| ID | Evidencia | Pregunta |
|---|---|---|
| I1 | Proceso root y `/app` escribible | ¿Cómo se escribió el archivo? |
| I2 | `docker history` antiguo muestra `DB_PASSWORD` | ¿Quedó expuesta la contraseña? |
| I3 | Postgres y Redis en `edge` | ¿Quién podía alcanzar la base? |
| I4 | Staging usa `latest`, sin gates | ¿Qué control faltó? |

---

# Antes de tocar nada

```bash
docker compose up -d
docker inspect tienda-segura-api-1 --format 'user={{.Config.User}} readonly={{.HostConfig.ReadonlyRootfs}}'
docker compose exec -T api sh -c 'id; ls -la /app | head'
docker history tienda-api:4.0 --no-trunc | grep -i pass || echo "sin secretos"
docker network inspect tienda_segura_edge --format '{{range .Containers}}{{.Name}} {{end}}'
```

Si se conserva el contenedor original, `docker diff` muestra los archivos añadidos.

---

# I1: reproducir la escritura

```bash
docker run --rm --user 0 --name prueba-escritura --entrypoint sh tienda-api:4.0 \
  -c 'touch /app/marcador && echo "escritura posible"'
```

`--user 0` simula el RC que corría como root. Compara con el stack endurecido:

```bash
docker compose exec -T api sh -c 'touch /app/marcador' || echo "/app protegido"
docker compose exec -T api sh -c 'grep -E "CapEff|NoNewPrivs" /proc/self/status'
```

La diferencia no está en el código. Está en cómo se ejecuta.

---

# I2: el secreto

```bash
docker history tienda-api:4.0 --no-trunc | grep -i pass || echo "sin secretos"
docker image inspect tienda-api:4.0 --format '{{json .Config.Env}}'
grep -n 'secrets' compose.yaml
```

La rotación real se documenta. No se cambia la contraseña del volumen en clase: un volumen inicializado no vuelve a leer `POSTGRES_PASSWORD_FILE`.

---

# I3: la red

```bash
docker network inspect tienda_segura_backend --format 'backend: {{range .Containers}}{{.Name}} {{end}}'
docker network inspect tienda_segura_edge --format 'edge: {{range .Containers}}{{.Name}} {{end}}'
```

Esperado: db, redis y api en `backend`. Solo api en `edge`.

La base no necesita salir a Internet para servir la API.

---

# I4: el gate que faltó

```bash
./ci/verificar-imagen.sh tienda-api:4.0
./ci/verificar-imagen.sh python:3.12-slim || true
MAX_MB=50 ./ci/verificar-imagen.sh tienda-api:4.0 || true
```

Usuario y tamaño son deterministas. No dependen del día ni de la base de CVEs.

Un gate así habría detenido la imagen antigua antes de staging.

---

# Laboratorio A y B

Laboratorio A, 60 min: evidencia, reproducción, secretos y redes.

Laboratorio B, 50 min: runtime restringido, gates y escaneo.

Guía: `lab/guia-paso-a-paso.md`, pasos 0 a 5.

Auditoría cruzada: `lab/retos-auditoria.md`, retos 1 a 3.

---

# ¿Y los CVEs?

```bash
trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed tienda-api:4.0
trivy image --format cyclonedx --output /tmp/tienda-api-sbom.json tienda-api:4.0
```

El archivo apareció por una configuración de runtime, no por un CVE de la base.

Escanear sigue siendo necesario. No sirve para explicar este incidente.

---

# Postmortem

```text
Línea de tiempo
Causa raíz
Evidencia I1, I2, I3, I4
Controles aplicados
Relación con los CVEs
Acciones pendientes con responsable y fecha
Decisión de publicación
```

Plantilla: `lab/informes/postmortem.md`.

---

# Decisión

Publicar: solo si los cuatro hallazgos están cerrados y la evidencia está en el informe.

Publicar con excepción: si queda una acción pendiente con responsable y fecha.

No publicar: si no se puede explicar cómo se escribió el archivo.

---

# Límites del caso

- No se ejecuta código malicioso.
- No se borran volúmenes.
- No se publica en un registry real.
- Sin Trivy, se lee `lab/informes/README.md` y se anota la limitación.

El caso se resuelve con Docker y Compose. No hace falta clúster.

---

# Cierre en 30 segundos

Cada pareja responde:

1. Qué pasó.
2. Qué control lo evita.
3. Si publicaría la versión final con la evidencia que tiene.

El grupo decide si la respuesta está respaldada por comandos.

---

<!--
Notas para el instructor:
- No corregir I1 antes de tiempo: la reproducción es el centro del caso.
- No cambiar la contraseña del volumen de Postgres en clase.
- Si el contenedor original no existe, documentar la pérdida de evidencia.
- Guardar 30 minutos para el postmortem y la decisión.
-->
