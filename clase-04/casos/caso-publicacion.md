# Caso 3: publicación con excepción, el CVE de la noche anterior

| Dato | Valor |
|---|---|
| Duración | 4 h |
| Participantes | 6, en parejas |
| Modalidad | Virtual, instructor proyecta desde su equipo |
| Requisitos | Docker Engine 24+, Compose v2.24+. Sin Kubernetes |
| Material base | `clase-04/lab/guia-paso-a-paso.md` y `clase-04/lab/compose.yaml` |
| Entregable | Acta de publicación con digest, gates, SBOM y disposición del CVE |

## Situación

Viernes, 22:15. La versión 4.0 está lista para publicarse a las 08:00 del sábado. El escaneo nocturno encontró un `HIGH` en la base Debian sin versión corregida. Operación quiere publicar igual: el cambio es de imagen base y no del código de la API. Seguridad quiere bloquear: nadie sabe si el paquete afectado está en la imagen que se va a publicar.

La pareja es el comité de publicación. Debe reconstruir el artefacto, ejecutar los gates, generar el SBOM y dejar una decisión escrita: publicar, publicar con excepción o no publicar.

## Hallazgos iniciales

| ID | Situación encontrada | Pregunta que responde la pareja |
|---|---|---|
| P1 | Staging desplegó `tienda-api:latest` | ¿Qué imagen se escaneó y qué imagen se publicaría? |
| P2 | No hay SBOM del artefacto de staging | ¿El paquete del CVE está realmente en la imagen? |
| P3 | El pipeline anterior solo medía tamaño | ¿Qué control habría detectado un usuario root? |
| P4 | Redis quedó sin `cap_drop: ALL` tras un reinicio | ¿Qué compensación existe mientras no se corrige el CVE? |

Este caso reutiliza el laboratorio del caso 1, pero cambia el orden: primero se decide qué artefacto se evalúa y después se analiza el CVE. El objetivo no es que todos lleguen a la misma decisión, sino que la decisión tenga evidencia.

## Agenda

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:25 | Comité de publicación: reglas de decisión y reparto de roles | Este archivo |
| 00:25-01:20 | Laboratorio A: reconstruir el artefacto y corregir regresiones | Guía pasos 1 a 3 |
| 01:20-01:30 | Pausa | sin material |
| 01:30-02:20 | Laboratorio B: gates en verde y en rojo | Guía paso 4 |
| 02:20-03:05 | Trivy, SBOM y lectura por capas | Guía paso 5 |
| 03:05-03:40 | Auditoría cruzada | `lab/retos-auditoria.md`, retos 1, 2 y 4 |
| 03:40-04:00 | Acta de publicación y demo de 3 minutos | Plantilla de este archivo |

## Laboratorio A: artefacto y regresiones

Construye la imagen con etiqueta de versión y comprueba qué identifica al artefacto:

```bash
cd clase-04/lab
docker compose build api
docker image inspect tienda-api:4.0 --format 'id={{.Id}} user={{.Config.User}} size={{.Size}}'
docker image inspect tienda-api:4.0 --format '{{json .Config.Labels}}'
docker history tienda-api:4.0 --no-trunc | grep -i pass || echo "sin secretos en el historial"
```

Una imagen construida en local no tiene `RepoDigests`. Ese valor aparece cuando el pipeline la publica en un registry. En clase se distingue entre el ID local, que identifica el build, y el digest de registry, que identifica el artefacto publicado.

Revisa la regresión de P4:

```bash
docker compose config | sed -n '/^  redis:/,/^  api:/p' | grep -E 'user:|cap_drop|ALL|read_only'
docker compose up -d
docker compose exec -T redis sh -c 'grep -E "Cap(Eff|Bnd)" /proc/self/status'
```

Si Redis quedó sin `cap_drop`, el valor de `CapEff` no es cero. Restaura el bloque del `compose.yaml` del caso 1 y comprueba que Redis sigue arrancando con `user: "999:1000"`.

Sobre P3, lee `ci/verificar-imagen.sh` y señala qué línea habría fallado con una imagen root. No hace falta crear un gate roto para entenderlo: el script actual comprueba usuario y tamaño, y las dos comprobaciones se ejecutan en el siguiente bloque.

## Laboratorio B: gates, escaneo y SBOM

```bash
./ci/verificar-imagen.sh tienda-api:4.0
./ci/verificar-imagen.sh python:3.12-slim || true
MAX_MB=50 ./ci/verificar-imagen.sh tienda-api:4.0 || true
trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed tienda-api:4.0
trivy image --format cyclonedx --output /tmp/tienda-api-sbom.json tienda-api:4.0
python3 - <<'PY'
import json
s = json.load(open('/tmp/tienda-api-sbom.json'))
print('componentes:', len(s.get('components', [])))
PY
```

Busca en el SBOM el paquete del aviso. Si el informe del día no trae un `HIGH` sin corrección, el instructor plantea la hipótesis como ejercicio: el equipo debe decir qué miraría y dónde lo anotaría.

La disposición del CVE se escribe con cinco campos: paquete, capa, versión corregida, exposición real y fecha de revisión. Sin esos campos, una excepción es solo una opinión.

## Entregable

Copia la plantilla siguiente a `clase-04/lab/informes/publicacion.md` y rellénala.

````markdown
# Acta de publicación: tienda-api 4.0

| Dato | Valor |
|---|---|
| Pareja |  |
| Decisión | Publicar / Publicar con excepción / No publicar |

## Artefacto evaluado

ID local:
Etiqueta:
Digest de registry, o motivo por el que no existe todavía:
Etiquetas OCI:

## Gates

Salida con la imagen endurecida:
Salida con `python:3.12-slim`:
Salida con `MAX_MB=50`:
Qué gate habría fallado en el pipeline anterior:

## Excepción por CVE

Paquete:
Capa, base Debian o dependencia Python:
Versión corregida:
¿El proceso afectado está en runtime?:
Compensaciones aplicadas, por ejemplo runtime de solo lectura o red interna:
Responsable:
Fecha de revisión:

## SBOM

Ruta del archivo:
Número de componentes:
Cómo se usó para responder la pregunta del paquete:

## Regresión de Redis

Estado antes:
Estado después:
Comprobación:

## Decisión

Por qué se publica, se publica con excepción o no se publica:

## Firma

Responsable de la pareja:
````

## Demo de 3 minutos

Cada pareja muestra tres cosas: el ID del artefacto evaluado, la salida de un gate en rojo y la disposición del CVE. Si la decisión es publicar con excepción, debe mencionar el responsable y la fecha de revisión.

## Límites del caso

- No se publica nada en un registry real. El digest se explica, no se genera.
- No se cambia el umbral de Trivy en `ci/verificar-imagen.sh` durante la clase. La excepción se escribe en el acta.
- No se desactiva `cap_drop` para "arreglar" Redis. La corrección es declarar el usuario.
- Si Trivy no está disponible, se usa `lab/informes/README.md` y la hipótesis del CVE se marca como ejercicio, no como hallazgo medido.
