# Clase 4: caso de estudio, auditoría de `tienda-api` 4.0

**Duración:** 4 h · **Participantes:** 6 · **Requisitos:** Docker Engine 24+ o Docker Desktop 4.30+ y Compose v2.24+. No se necesita Kubernetes.

## Caso 1: auditoría previa al lanzamiento

El equipo va a publicar la versión 4.0 de la API de la tienda. Un auditor externo entregó cuatro hallazgos el viernes anterior al lanzamiento:

| Hallazgo | Lo que dice el informe |
|---|---|
| H1 | La imagen corre como root, conserva pip en runtime y el código pertenece a root |
| H2 | No hay evidencia de dónde vive la contraseña ni de que quede fuera del historial de la imagen |
| H3 | El runtime no limita capacidades ni escritura, y la base y Redis comparten red con el exterior |
| H4 | El pipeline publica por `latest`, sin gates, sin SBOM y sin criterio para interpretar CVEs |

La clase se trabaja en parejas. Cada pareja es el equipo de plataforma: cierra los cuatro hallazgos con Docker y Compose, guarda la evidencia y al final firma un acta de salida con decisión de publicar o no publicar. El caso da sentido a cada comando: nada se hace solo porque sí.

## Casos disponibles

El laboratorio es el mismo para los tres guiones. Cambia el encargo, el orden de trabajo y el entregable.

| Caso | Situación | Entregable | Diapositivas |
|---|---|---|---|
| Caso 1, auditoría previa | Informe del auditor antes del lanzamiento | Acta de salida | [`slides.pptx`](slides.pptx) |
| [Caso 2, incidente](casos/caso-incidente.md) | Aparece un archivo inesperado en `/app` | Informe postmortem | [`caso-incidente.pptx`](casos/caso-incidente.pptx) |
| [Caso 3, publicación con excepción](casos/caso-publicacion.md) | CVE nuevo sin corrección la noche anterior | Acta de publicación | [`caso-publicacion.pptx`](casos/caso-publicacion.pptx) |

Los casos 2 y 3 usan los mismos archivos de `lab/`. No añaden contenedores ni requieren más memoria que el caso 1.

## Materiales

| Archivo | Para qué |
|---|---|
| `slides.md` | Diapositivas (Marp). Renderizar con `marp slides.md -o slides.pdf` o proyectar el Markdown |
| `slides.pptx` | Presentación lista para proyectar |
| `extra-60-min.md` | Tres bloques de 20 min si el grupo termina antes |
| `guia-docente.md` | Guion de sesión: preparación, tiempos, checkpoints y planes B |
| `casos/` | Dos guiones alternativos de 4 horas sobre el mismo laboratorio |
| `lab/guia-paso-a-paso.md` | Guía del alumno, organizada por los cuatro hallazgos |
| `lab/retos-auditoria.md` | Auditoría cruzada en parejas, cuatro comprobaciones |
| `lab/compose.yaml` | Stack con runtime endurecido, secretos y red interna |
| `lab/ci/verificar-imagen.sh` | Gates deterministas de usuario y tamaño |
| `lab/ci/github-actions-ci.yml` | Workflow de ejemplo para copiar a `.github/workflows/` |
| `lab/informes/acta-ejemplo.md` | Plantilla del acta de salida |
| `../clase-02/lab/app/Dockerfile.hardened` | Imagen endurecida de la misma aplicación |
| `demos/01-runtime-endurecido.sh` · `demos/02-escaneo-trivy.sh` · `demos/03-gates-ci.sh` | Demos del caso |
| `evaluacion/rubrica-clase-04.md` | Rúbrica del entregable |
| `recursos/checklist-seguridad.md` | Checklist imprimible |

## Cómo usar este material

**Instructor**

1. Construye la imagen y levanta el stack antes de clase. El primer build tarda menos si `python:3.12-slim` ya está descargada.
2. Pre-descarga la base de Trivy si vas a escanear en la sesión. Si no está, abre el informe guardado en `lab/informes/` y sigue con el método sin esperar una descarga.
3. Proyecta `slides.pptx`, presenta el caso en la diapositiva 2 y vuelve a él en cada bloque. `guia-docente.md` trae los tiempos y los checkpoints.
4. Ten a mano el error de Redis con `cap_drop: ALL`. Es la discusión central del caso: un control copiado sin probar rompe el servicio.
5. Usa `lab/retos-auditoria.md` en la auditoría cruzada. Los cuatro retos son parte del plan; si hay emergencia de tiempo, haz el 1 y el 3 y deja el resto para casa.
6. Si el grupo termina antes, `extra-60-min.md` tiene tres bloques de 20 min: Trivy a fondo, runtime a mano y secretos de build con digest.

**Alumno**

1. Sigue `lab/guia-paso-a-paso.md` en orden. Cada paso cierra un hallazgo del informe.
2. No des por cerrado el hallazgo 3 sin ver `/app` de solo lectura y `CapEff` en cero.
3. Rellena el acta de `lab/informes/acta-ejemplo.md` con tus respuestas reales antes de entregar.

## Agenda (240 min)

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:15 | Presentación del caso y verificación del entorno | `docker compose ps` |
| 00:15-00:45 | Lectura del informe: superficie, imagen, runtime, secretos y cadena de suministro | `slides.md` |
| 00:45-01:40 | Laboratorio A: cerrar los hallazgos 1, 2 y 3 | `lab/guia-paso-a-paso.md` pasos 0-3 |
| 01:40-01:50 | Pausa | sin material |
| 01:50-02:25 | Hallazgo 4: CVEs, SBOM, gates y etapas del pipeline | `slides.md` + `demos/02-escaneo-trivy.sh` |
| 02:25-03:10 | Laboratorio B: gates, escaneo y acta de salida | `lab/guia-paso-a-paso.md` pasos 4-6 |
| 03:10-03:45 | Auditoría cruzada en parejas | `lab/retos-auditoria.md` |
| 03:45-04:00 | Acta, entregable y cierre del curso | `evaluacion/rubrica-clase-04.md` |

## Hallazgos y dónde se cierran

| Hallazgo | Bloque | Evidencia que se entrega |
|---|---|---|
| H1, imagen con privilegios | Pasos 1 y 2 | `docker image inspect`, uid en ejecución, tamaño y sin pip |
| H2, contraseña sin rastro | Paso 3 | `docker history` sin contraseñas y secreto montado desde archivo |
| H3, runtime abierto | Paso 3 | `/app` de solo lectura, `CapEff` en cero, redes separadas |
| H4, pipeline sin control | Pasos 4, 5 y 6 | Gates en verde y en rojo, informe de Trivy, SBOM y acta |
| Auditoría cruzada | Retos 1 a 4 | Un hallazgo explicado por pareja con su control |

## Conceptos clave

- **La imagen es un artefacto.** Se construye una vez, se identifica por digest y se escanea. `latest` no identifica nada.
- **Endurecer la imagen.** Usuario sin privilegios, sin shell de login, sin pip en runtime y con etiquetas que permitan rastrearla.
- **Endurecer el runtime.** Solo lectura, `cap_drop: ALL`, `no-new-privileges`, `tmpfs` y límites de recursos.
- **Secretos fuera de las capas.** Un `ARG` o un `ENV` con la contraseña queda en el historial. Se monta en ejecución.
- **Gates deterministas.** Usuario y tamaño dependen de lo que el equipo cambió, no del día en que corre el pipeline.
- **Trivy como informe.** Prioriza y documenta. Si se convierte en gate, que sea con umbral, fecha y excepciones.
- **SBOM.** Responde qué lleva la imagen y permite reaccionar cuando aparece un CVE.
- **El endurecimiento tiene costes.** Redis necesita un usuario explícito si se quita `CAP_SETUID`. Cada control se prueba con la imagen concreta.

## Guion de demos

1. **Runtime endurecido** (`demos/01-runtime-endurecido.sh`): uid 10001, `/app` de solo lectura, capacidades cero y dos redes. Preguntar: *¿qué impide que un proceso comprometido escriba un binario?*
2. **Escaneo** (`demos/02-escaneo-trivy.sh`): CVEs de la base y de Python, SBOM CycloneDX. Preguntar: *¿qué CVE se arregla con un rebuild y cuál no?*
3. **Gates** (`demos/03-gates-ci.sh`): la imagen endurecida pasa; `python:3.12-slim` falla por root; un límite bajo falla por tamaño. Preguntar: *¿por qué el gate no es la lista de CVEs?*

## Errores comunes y cómo resolverlos

| Síntoma | Causa | Solución |
|---|---|---|
| Redis reinicia con `setpriv: setresuid failed` | `cap_drop: ALL` quita `CAP_SETUID` | Declarar `user: "999:1000"` |
| El puerto 18030 no aparece | La API solo está en la red interna | Añadir `edge` |
| `Read-only file system` | El proceso escribe en `/app` o `/tmp` | `tmpfs: /tmp` y `PYTHONDONTWRITEBYTECODE=1` |
| El gate no puede leer el uid | La imagen no tiene Python | Ajustar el comando del gate |
| Trivy tarda o falla por red | Primera descarga de la base | Pre-descargar o ejecutar en el runner |
| El SARIF no aparece | Falta `security-events: write` | Añadir el permiso |
| La contraseña aparece en `docker history` | Se pasó como `ARG` o `ENV` | Montar el secreto en ejecución |

## Evaluación

- Entregable: acta de salida, stack endurecido, salida de los gates, informe de Trivy y SBOM.
- Rúbrica: `evaluacion/rubrica-clase-04.md` (10 % del curso).
- Demo oral (3 min): explicar un control de imagen, uno de runtime y por qué el gate no es el escaneo.

## Preparación del aula

```bash
docker pull python:3.12-slim
docker pull postgres:16-alpine
docker pull redis:7-alpine

cd clase-04/lab
cp secrets/db_password.txt.example secrets/db_password.txt
docker compose build api
docker compose up -d
./ci/verificar-imagen.sh tienda-api:4.0

# Opcional: pre-descargar la base de Trivy
trivy image --download-db-only

# Comprobar el puerto
ss -ltn | grep 18030 || echo "18030 libre"
```

Cada participante trabaja en su equipo y el puerto 18030 suele estar libre. Si dos personas comparten host, asigna un puerto (`18030 + n`) y un nombre de proyecto (`tienda-segura-ana`). El clúster de la clase 3 no se usa en esta sesión y puede seguir parado.
