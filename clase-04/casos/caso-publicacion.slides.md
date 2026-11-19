---
marp: true
theme: default
paginate: true
header: "Docker Avanzado · Clase 4 · Caso 3"
style: |
  section { font-size: 22px; }
---

# Caso 3: publicación con excepción

## El CVE de la noche anterior

4 horas · 6 participantes · Docker y Compose

---

# La situación

Viernes, 22:15. La versión 4.0 saldrá mañana a las 08:00.

El escaneo nocturno encontró un `HIGH` en Debian sin versión corregida.

Operación quiere publicar. Seguridad quiere bloquear. Nadie sabe si el paquete está en la imagen.

---

# El comité de publicación

La pareja decide:

- Publicar.
- Publicar con excepción.
- No publicar.

La decisión no puede basarse en el color del informe. Debe apoyarse en el artefacto, el SBOM y los gates.

---

# Hallazgos iniciales

| ID | Situación | Pregunta |
|---|---|---|
| P1 | Staging usa `tienda-api:latest` | ¿Qué imagen se escaneó? |
| P2 | No hay SBOM | ¿El paquete está en la imagen? |
| P3 | Gate anterior solo medía tamaño | ¿Se habría detectado un root? |
| P4 | Redis quedó sin `cap_drop` | ¿Qué control compensa el CVE? |

---

# Reglas de decisión

Una excepción necesita cinco campos:

1. Paquete y capa.
2. Versión corregida.
3. Exposición real en runtime.
4. Compensaciones aplicadas.
5. Responsable y fecha de revisión.

Sin esos campos, la excepción es una opinión.

---

# Agenda

| Hora | Bloque |
|---|---|
| 00:00-00:25 | Comité y reglas |
| 00:25-01:20 | Artefacto y regresiones |
| 01:30-02:20 | Gates en verde y en rojo |
| 02:20-03:05 | Trivy y SBOM |
| 03:05-03:40 | Auditoría cruzada |
| 03:40-04:00 | Acta y demo |

Pausa a las 01:20.

---

# P1: qué artefacto se evaluó

```bash
docker compose build api
docker image inspect tienda-api:4.0 --format 'id={{.Id}} user={{.Config.User}} size={{.Size}}'
docker image inspect tienda-api:4.0 --format '{{json .Config.Labels}}'
```

El ID local identifica el build. El digest de registry identifica lo publicado.

Una imagen construida en local no tiene `RepoDigests`. Ese dato aparece al publicar.

---

# P2: buscar el paquete

```bash
trivy image --format cyclonedx --output /tmp/tienda-api-sbom.json tienda-api:4.0
python3 - <<'PY'
import json
s = json.load(open('/tmp/tienda-api-sbom.json'))
print('componentes:', len(s.get('components', [])))
PY
```

El SBOM responde qué lleva la imagen sin reconstruirla.

---

# P3: el gate que faltó

```bash
./ci/verificar-imagen.sh tienda-api:4.0
./ci/verificar-imagen.sh python:3.12-slim || true
MAX_MB=50 ./ci/verificar-imagen.sh tienda-api:4.0 || true
```

Usuario root falla antes de publicar. Tamaño también.

El pipeline anterior solo miraba tamaño: la imagen root habría pasado.

---

# P4: regresión en Redis

```bash
docker compose config | sed -n '/^  redis:/,/^  api:/p' | grep -E 'user:|cap_drop|ALL|read_only'
docker compose up -d
docker compose exec -T redis sh -c 'grep -E "Cap(Eff|Bnd)" /proc/self/status'
```

Sin `cap_drop`, `CapEff` no es cero.

Restaurar el bloque del caso 1. Redis sigue arrancando con `user: "999:1000"`.

---

# Laboratorio A

1. Construir con etiqueta de versión.
2. Leer ID, usuario y etiquetas OCI.
3. Comprobar secretos en el historial.
4. Restaurar `cap_drop` en Redis.
5. Verificar que el stack sigue sano.

Guía: `lab/guia-paso-a-paso.md`, pasos 1 a 3.

---

# Laboratorio B

1. Gates en verde con la imagen endurecida.
2. Gate en rojo con la imagen base.
3. Gate en rojo con límite bajo.
4. Escaneo con severidad HIGH y CRITICAL.
5. SBOM en CycloneDX.

Guía: `lab/guia-paso-a-paso.md`, pasos 4 y 5.

---

# Leer el CVE por capas

| Capa | Origen | Acción |
|---|---|---|
| Debian | Imagen base | Actualizar base y reconstruir |
| Python | `requirements.txt` | Subir versión de la dependencia |
| Sin corrección | Base o dependencia | Mitigar o aceptar por escrito |

La pregunta no es cuántos CVEs hay. Es qué parte del stack afectan.

---

# Excepción con fecha

```text
Paquete:
Capa:
Versión corregida:
Exposición real:
Compensaciones:
Responsable:
Fecha de revisión:
```

Una excepción permanente no es una excepción. Es una imagen sin control.

---

# Auditoría cruzada

Retos de `lab/retos-auditoria.md`:

1. Secreto en el historial.
2. Capacidad de más.
3. Etiqueta móvil en el `FROM`.

Lo que se compara no es la velocidad, sino la evidencia: cada pareja muestra un comando y su salida.

---

# Acta de publicación

```text
Artefacto evaluado
Salida de los gates
Disposición del CVE
SBOM y número de componentes
Estado de Redis antes y después
Decisión y firma
```

Plantilla: `lab/informes/publicacion.md`.

---

# Demo de 3 minutos

Cada pareja muestra:

1. El ID del artefacto evaluado.
2. Un gate en rojo.
3. La disposición del CVE con responsable y fecha.

Si decide publicar con excepción, dice qué compensación aplicó.

---

# Límites y cierre

- No se publica en un registry real.
- No se cambia el umbral de Trivy para forzar el verde.
- No se quita `cap_drop` para arreglar Redis.
- Sin Trivy, se usa `lab/informes/README.md`.

La decisión correcta es la que puede demostrarse.

---

<!--
Notas para el instructor:
- Mantener la presión de la fecha, pero no convertirla en una respuesta única.
- Si el informe del día no trae un HIGH sin corrección, plantearlo como hipótesis.
- No dejar que el grupo use el número de CVEs como único criterio.
- Guardar 20 minutos para el acta y la demo.
-->
