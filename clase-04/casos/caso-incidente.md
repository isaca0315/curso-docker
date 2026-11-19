# Caso 2: incidente, archivo inesperado en `/app`

| Dato | Valor |
|---|---|
| Duración | 4 h |
| Participantes | 6, en parejas |
| Modalidad | Virtual, instructor proyecta desde su equipo |
| Requisitos | Docker Engine 24+, Compose v2.24+. Sin Kubernetes |
| Material base | `clase-04/lab/guia-paso-a-paso.md` y `clase-04/lab/compose.yaml` |
| Entregable | Informe postmortem con decisión de publicación |

## Situación

Lunes, 07:40. El servicio de staging con `tienda-api:4.0-rc1` levantó una alerta: apareció `/app/.cache/parche.sh`, un archivo que nadie desplegó. El ingeniero de guardia paró el contenedor y conservó el volumen de Postgres. No hay señales de salida de datos, pero nadie puede explicar cómo se escribió ese archivo.

El lanzamiento de la versión final está previsto para las 16:00. La pareja debe reconstruir qué pasó, cerrar las causas con Docker y Compose y decidir si se publica.

## Hallazgos iniciales

| ID | Evidencia del incidente | Pregunta que responde la pareja |
|---|---|---|
| I1 | El proceso corría como root y `/app` era escribible | ¿Qué permitió que el archivo quedara en la imagen del contenedor? |
| I2 | `docker history` de una imagen antigua muestra `DB_PASSWORD` | ¿La contraseña usada en staging quedó expuesta? |
| I3 | Postgres y Redis aparecen en la red `edge` | ¿Quién podía alcanzar la base desde el host? |
| I4 | Staging recibió la imagen por `latest`, sin gates | ¿Qué control habría detenido esta imagen? |

El caso se apoya en los mismos archivos que el caso 1. Cambia el punto de partida: aquí hay un incidente y hay que preservar evidencia antes de tocar nada.

## Agenda

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:20 | Lectura del incidente y reparto de roles | Este archivo |
| 00:20-01:20 | Laboratorio A: preservar evidencia y reproducir la escritura | Guía pasos 0 a 3 |
| 01:20-01:30 | Pausa | sin material |
| 01:30-02:20 | Laboratorio B: cerrar imagen, secretos y red | Guía paso 3 |
| 02:20-02:50 | Gates, Trivy y SBOM | Guía pasos 4 y 5 |
| 02:50-03:30 | Auditoría cruzada | `lab/retos-auditoria.md`, retos 1 a 3 |
| 03:30-04:00 | Postmortem y decisión de publicación | Plantilla de este archivo |

## Laboratorio A: evidencia y reproducción

Antes de cambiar nada, cada pareja recolecta la configuración efectiva:

```bash
cd clase-04/lab
docker compose up -d
docker inspect tienda-segura-api-1 --format 'user={{.Config.User}} readonly={{.HostConfig.ReadonlyRootfs}} capdrop={{.HostConfig.CapDrop}}'
docker compose exec -T api sh -c 'id; ls -la /app | head'
docker history tienda-api:4.0 --no-trunc | grep -i pass || echo "sin secretos en el historial"
docker network inspect tienda_segura_edge --format 'edge: {{range .Containers}}{{.Name}} {{end}}'
```

Si se conserva el contenedor del incidente, `docker diff <contenedor>` muestra los archivos añadidos. Si ya no existe, se trabaja con la imagen y se documenta que la evidencia original se perdió. Ese detalle también entra en el postmortem.

Reproduce la condición I1 con un contenedor desechable, sin las opciones del compose:

```bash
docker run --rm --name prueba-escritura --entrypoint sh tienda-api:4.0 \
  -c 'touch /app/marcador && echo "escritura posible"'
```

Compara con el stack endurecido:

```bash
docker compose exec -T api sh -c 'touch /app/marcador' || echo "/app protegido en el stack"
docker compose exec -T api sh -c 'grep -E "Cap(Eff|NoNewPrivs)" /proc/self/status'
```

Sobre I2, la pareja solo documenta la rotación. No cambia la contraseña del volumen de Postgres en clase: un volumen ya inicializado no vuelve a leer `POSTGRES_PASSWORD_FILE`. La evidencia que se entrega es la comprobación de que la contraseña no está en la imagen y de que el secreto se monta desde archivo.

Sobre I3, compara las dos redes con `docker network inspect`. La base y Redis deben aparecer solo en `backend`.

## Laboratorio B: cierre y gates

Seguir el paso 3 de la guía para dejar el stack con `read_only`, `tmpfs`, `cap_drop: ALL` y `no-new-privileges`. Después ejecutar:

```bash
./ci/verificar-imagen.sh tienda-api:4.0
./ci/verificar-imagen.sh python:3.12-slim || true
MAX_MB=50 ./ci/verificar-imagen.sh tienda-api:4.0 || true
trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed tienda-api:4.0
trivy image --format cyclonedx --output /tmp/tienda-api-sbom.json tienda-api:4.0
```

La pregunta del bloque es si un CVE nuevo tiene algo que ver con este incidente. Normalmente no: el archivo apareció por una configuración de runtime, no por una vulnerabilidad de la base. Esa distinción evita que el equipo culpe al escaneo de un fallo de configuración.

## Entregable

Copia la plantilla siguiente a `clase-04/lab/informes/postmortem.md` y rellénala.

````markdown
# Postmortem: archivo inesperado en /app

| Dato | Valor |
|---|---|
| Pareja |  |
| Decisión | Publicar / Publicar con excepción / No publicar |

## Línea de tiempo

- 07:40:
- 07:55:
- 08:10:

## Causa raíz

Qué configuración permitió la escritura y dónde se ve:

```text
```

## Evidencia por hallazgo

I1:
I2:
I3:
I4:

## Controles aplicados

Qué se cambió en la imagen:
Qué se cambió en el runtime:
Qué gate habría detenido la imagen antigua:

## Relación con los CVEs

¿El escaneo explica este incidente? Por qué:

## Acciones pendientes

- Rotación de contraseña, con responsable y fecha:
- Fijación de digest, con responsable y fecha:
- Revisión de la red `edge`, con responsable y fecha:

## Firma

Responsable de la pareja:
````

## Cierre en 30 segundos

Cada pareja responde tres preguntas: qué pasó, qué control lo evita y si publicaría la versión final con la evidencia que tiene. El resto del grupo decide si la respuesta está respaldada por comandos o solo por la narrativa.

## Límites del caso

- No se ejecuta código malicioso. La reproducción es un `touch` en un contenedor desechable.
- No se borran volúmenes. El incidente exige conservar datos.
- No se publica la imagen en ningún registry. La decisión queda escrita en el informe.
- Si Trivy no está disponible, se lee `lab/informes/README.md` y se marca la limitación en el postmortem.
