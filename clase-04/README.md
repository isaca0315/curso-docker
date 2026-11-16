# Clase 4: seguridad de la imagen y pipeline de CI/CD

**Duración:** 4 h · **Participantes:** 6 · **Requisitos:** Docker Engine 24+ o Docker Desktop 4.30+, Docker Compose v2.24+, `kind` y `kubectl` de la clase 3

## Materiales

| Archivo | Para qué |
|---|---|
| `slides.md` | Diapositivas (Marp). Renderizar con `marp slides.md -o slides.pdf` o proyectar el Markdown |
| `slides.pptx` | Presentación lista para proyectar (exportada de `slides.md`) |
| `extra-60-min.md` | Tres bloques de 20 min si el grupo termina antes |
| `guia-docente.md` | Guion de sesión: preparación, tiempos, checkpoints y planes B |
| `lab/guia-paso-a-paso.md` | Guía del alumno con resultados medidos y diagnóstico |
| `lab/retos-auditoria.md` | Cuatro comprobaciones de auditoría para el bloque de cierre |
| `lab/compose.yaml` | Stack con runtime endurecido y red interna |
| `lab/ci/verificar-imagen.sh` | Gates deterministas de usuario y tamaño |
| `lab/ci/github-actions-ci.yml` | Workflow de ejemplo para copiar a `.github/workflows/` |
| `lab/k8s/` | Overlay de Kustomize sobre los manifiestos de la clase 3 |
| `../clase-02/lab/app/Dockerfile.hardened` | Imagen endurecida de la misma aplicación |
| `demos/01-runtime-endurecido.sh` | Usuario, solo lectura, capacidades y redes |
| `demos/02-escaneo-trivy.sh` | CVEs y SBOM |
| `demos/03-gates-ci.sh` | Gates en verde y en rojo |
| `evaluacion/rubrica-clase-04.md` | Rúbrica del entregable |
| `recursos/checklist-seguridad.md` | Checklist imprimible |

## Cómo usar este material

**Instructor**

1. Construye la imagen y levanta el stack antes de clase. El primer build tarda menos si `python:3.12-slim` ya está descargada.
2. Pre-descarga la base de datos de Trivy si vas a escanear en la sesión: la primera ejecución tarda varios minutos.
3. Proyecta `slides.pptx` y sigue `guia-docente.md` para los tiempos, los checkpoints y la ruta sin Trivy.
4. Ten a mano el error de Redis con `cap_drop: ALL`. Es la mejor discusión de la clase: el endurecimiento tiene costes y hay que entender la imagen.
5. Si el equipo no tiene clúster de la clase 3, el paso 6 del lab es opcional. El resto no depende de Kubernetes.
6. Usa `lab/retos-auditoria.md` en el bloque de cierre: los cuatro retos son parte del plan. Solo si surge una emergencia de tiempo, haz los retos 1 y 3 y deja el resto para casa.
7. Si el grupo termina antes, `extra-60-min.md` tiene tres bloques de 20 min: Trivy a fondo, runtime a mano y secretos de build con digest.

**Alumno**

1. Sigue `lab/guia-paso-a-paso.md` en orden.
2. No avances del paso 3 sin ver `/app` de solo lectura y `CapEff` en cero.
3. Usa `recursos/checklist-seguridad.md` antes de entregar.

## Agenda (240 min)

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:15 | Repaso de la clase 3 y dudas | `kubectl get pods`, preguntas del lab 3 |
| 00:15-00:55 | Modelo de amenazas: imagen, runtime, secretos, supply chain, privilegios | `slides.md` |
| 00:55-01:50 | Lab 4a: Dockerfile endurecido, identidad, tamaño, runtime de solo lectura | `lab/guia-paso-a-paso.md` pasos 0-3 |
| 01:50-02:00 | Pausa | sin material |
| 02:00-02:40 | CVEs, SBOM, firmas, gates deterministas y etapas del pipeline | `slides.md` + `demos/02-escaneo-trivy.sh` |
| 02:40-03:25 | Lab 4b: gates, escaneo, SBOM, overlay en Kubernetes y GitHub Actions | `lab/guia-paso-a-paso.md` pasos 4-7 |
| 03:25-03:55 | Retos de auditoría en parejas | `lab/retos-auditoria.md` |
| 03:55-04:00 | Entregable, cierre del curso y siguientes pasos | `evaluacion/rubrica-clase-04.md` |

## Conceptos clave

- **La imagen es un artefacto.** Se versiona, se escanea, se firma y se despliega por digest. `latest` no identifica nada.
- **Endurecer la imagen.** Usuario sin privilegios, sin shell de login, sin pip en runtime y con etiquetas que permitan rastrearla.
- **Endurecer el runtime.** Solo lectura, `cap_drop: ALL`, `no-new-privileges`, `seccomp` y límites de recursos.
- **Secretos fuera de las capas.** Un `ARG` o un `ENV` con la contraseña queda en el historial. Se monta en ejecución.
- **Gates deterministas.** Usuario y tamaño dependen de lo que el equipo cambió. Los CVEs dependen del mundo.
- **Trivy como informe.** Prioriza y documenta. Si se convierte en gate, que sea con umbral, fecha y excepciones.
- **SBOM.** Responde qué lleva la imagen y permite reaccionar cuando aparece un CVE.
- **Pipeline por etapas.** Build, test, gates, escaneo, firma, publicación y despliegue con aprobación.
- **El endurecimiento tiene costes.** Redis necesita `CAP_SETUID` o un usuario explícito; Postgres necesita escribir en su volumen. Cada control se justifica.

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
| `ImagePullBackOff` | La imagen no está en el nodo | `kind load docker-image` |
| El overlay no encuentra la base | Directorio incorrecto | Ejecutar desde `lab/` con `-k k8s` |
| La contraseña aparece en `docker history` | Se pasó como `ARG` | Montar el secreto en ejecución |

## Evaluación

- Entregable: stack endurecido, salida de los gates, informe de Trivy y SBOM.
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

Cada participante trabaja en su equipo y el puerto 18030 suele estar libre. Si dos personas comparten host, asigna un puerto (`18030 + n`) y un nombre de proyecto (`tienda-segura-ana`).
