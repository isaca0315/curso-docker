# Curso de Docker Avanzado

**Duración:** 16 h (4 clases de 4 h); el mínimo pedido era 14 h
**Participantes:** 6
**Modalidad:** remota; cada participante ejecuta el laboratorio en su equipo y el instructor comparte pantalla.
**Requisitos:** saber usar la terminal, nociones de Linux (procesos, puertos, permisos) y de Docker básico (`docker run`, `docker ps`, `docker build`)


## Hilo conductor

Todas las clases giran sobre la misma aplicación: una API pequeña (`tienda-api`) con PostgreSQL y Redis.

| Clase | Qué se hace con la app |
|---|---|
| 1 | Se construye su imagen optimizada (multi-stage) |
| 2 | Se levanta el stack completo con Compose y redes separadas |
| 3 | Se despliega en Kubernetes local (kind) y se opera |
| 4 | Se asegura la imagen y se automatiza el pipeline de despliegue |

El ciclo de vida completo queda conectado entre clases.


## Clase 1: arquitectura, configuración y construcción de imágenes

**Objetivos:** entender qué hay debajo de `docker run`, configurar el daemon con criterio y construir imágenes propias pequeñas, reproducibles y seguras.

**Material de la clase:** [`clase-01/`](clase-01/README.md) (guía del instructor, diapositivas, lab, demos y rúbrica).

| Hora | Bloque |
|---|---|
| 00:00-00:20 | Bienvenida, diagnóstico del grupo, verificación de entornos (`docker info`, `kind version`) |
| 00:20-01:00 | **Arquitectura y características de Docker**: cliente, daemon, containerd y runc, shims, namespaces y cgroups, capas y overlay2, formato OCI, ciclo de vida de un contenedor |
| 01:00-01:45 | **Configuración de Docker**: `daemon.json`, storage drivers, límites de CPU/memoria, log drivers y rotación, `data-root`, contextos remotos, Docker rootless, cgroups v2 |
| 01:45-01:55 | Pausa |
| 01:55-02:15 | **Construcción de imágenes**: Dockerfile, instrucciones, caché de capas, BuildKit, multi-stage con etapa de test, `.dockerignore`, distroless/alpine, tagging y versionado |
| 02:15-03:15 | **Lab 1**: imagen multi-stage de `tienda-api`; comparar tamaño contra build ingenuo; inspeccionar capas (`docker history`, `dive`); aplicar límites de CPU/memoria; configurar rotación de logs en el daemon |
| 03:15-03:25 | Pausa |
| 03:25-04:00 | **Lab 1 (cierre)**: rebuild con caché en frío vs caliente y medición; reto: bajar la imagen por debajo de 100 MB sin romper la app; variante distroless y su costo de depuración; puesta en común y cierre |

**Entregable:** Dockerfile multi-stage con etapa de test funcionando + informe de 5 líneas con tamaños y tiempos medidos.

**Extra opcional (40 min):** [`clase-01/extra-compose/`](clase-01/extra-compose/README.md). Con la imagen optimizada ya construida, el grupo pasa de un `docker run` largo a un `compose.yaml` con API y proxy, límites y logs. Sirve de puente hacia la clase 2.


## Clase 2: Compose y networking avanzado

**Objetivos:** describir aplicaciones multi-contenedor de forma declarativa y diagnosticar problemas de red, DNS y conectividad entre contenedores.

**Material de la clase:** [`clase-02/`](clase-02/README.md) (guía del instructor, guion de sesión, diapositivas, lab, retos, demos y rúbrica).

| Hora | Bloque |
|---|---|
| 00:00-00:15 | Repaso y dudas de la clase 1 |
| 00:15-00:55 | **Docker Compose**: servicios, redes, volúmenes, variables de entorno, `env_file`, secrets, `depends_on` + `healthcheck`, profiles, override files, `docker compose watch` |
| 00:55-01:50 | **Lab 2a**: stack `api + postgres + redis + reverse proxy`; arranque ordenado con healthchecks; separar red `frontend` y `backend`; persistencia con volúmenes |
| 01:50-02:00 | Pausa |
| 02:00-02:40 | **Networking avanzado**: bridge por defecto vs user-defined, DNS embebido, `host`, `none`, `macvlan`, `overlay` (concepto y demo), publicación de puertos, MTU, reglas iptables/nftables, troubleshooting con `netshoot` |
| 02:40-03:25 | **Lab 2b**: verificar aislamiento entre redes; romper el DNS a propósito y diagnosticarlo; capturar tráfico con `netshoot`; comparar `host` vs bridge |
| 03:25-03:50 | **Retos de diagnóstico**: 504 por upstream caído, DNS inexistente, puerto equivocado y secreto viejo; trabajo en parejas |
| 03:50-04:00 | Entregable y cierre: ¿por qué un contenedor no ve a otro por `localhost`? |

**Entregable:** `compose.yaml` del stack + guía de diagnóstico de red de 10 líneas.


## Clase 3: muchas aplicaciones: orquestación y Kubernetes en acción

**Objetivos:** reconocer por qué el despliegue manual deja de escalar y operar una aplicación real en Kubernetes: despliegue, auto-reparación, escalado y actualizaciones sin caída.

**Material de la clase:** [`clase-03/`](clase-03/README.md) (guía del instructor, guion de sesión, diapositivas, lab, retos, demos y rúbrica). Para un día completo: [`clase-03/plan-8h.md`](clase-03/plan-8h.md).

| Hora | Bloque |
|---|---|
| 00:00-00:15 | Repaso y dudas de la clase 2 |
| 00:15-00:55 | **De Compose a Kubernetes**: desafíos de muchas aplicaciones, orquestación, estado deseado, pods, Deployments, Services, Ingress, probes, requests/limits y HPA |
| 00:55-01:50 | **Lab 3a**: clúster local con `kind`; desplegar `tienda-api` + Postgres con manifiestos; `Secret`; liveness/readiness; Service e Ingress; auto-reparación |
| 01:50-02:00 | Pausa |
| 02:00-02:40 | **Operación**: rolling update con `maxSurge`/`maxUnavailable`, rollback, readiness frente a liveness, demos |
| 02:40-03:15 | **Lab 3b**: Ingress por nombre de host, actualización sin caída y probe rota |
| 03:15-03:25 | **HPA con carga** (si `metrics-server` está disponible) |
| 03:25-03:50 | **Retos de diagnóstico**: pod `Pending`, Service sin endpoints, secreto viejo y puerto del Ingress; trabajo en parejas |
| 03:50-04:00 | Entregable y cierre: `kompose` como puente Compose → K8s y qué conviene no migrar tal cual |

**Entregable:** manifiestos YAML aplicados + captura de `kubectl rollout history` y del rollback.


## Clase 4: caso de estudio, auditoría de `tienda-api` 4.0

**Objetivos:** cerrar los cuatro hallazgos de un informe de auditoría con Docker y Compose: imagen sin privilegios, secretos fuera de las capas, runtime restringido y pipeline con gates, SBOM y criterio de publicación. No se usa Kubernetes.

**Material de la clase:** [`clase-04/`](clase-04/README.md) (guía del instructor, guion de sesión, diapositivas, lab, retos, demos y rúbrica).

| Hora | Bloque |
|---|---|
| 00:00-00:15 | Presentar el caso y verificar Docker y Compose |
| 00:15-00:45 | Superficie de ataque: imagen, runtime, secretos y cadena de suministro |
| 00:45-01:40 | **Laboratorio A**: cerrar H1, H2 y H3 con el Dockerfile endurecido, secretos y runtime restringido |
| 01:40-01:50 | Pausa |
| 01:50-02:25 | **Hallazgo 4**: CVEs, SBOM, gates deterministas y etapas del pipeline |
| 02:25-03:10 | **Laboratorio B**: gates en verde y en rojo, Trivy como informe y acta de salida |
| 03:10-03:45 | **Auditoría cruzada**: secreto en la imagen, capacidad de más, `read_only` sin `tmpfs` y etiqueta móvil |
| 03:45-04:00 | Acta, entregable y cierre del curso |

**Entregable:** acta de salida con evidencia de los cuatro hallazgos, stack endurecido, gates, informe de escaneo y SBOM.


## Proyecto integrador (transversal)

Al final de la clase 4 cada participante entrega el recorrido completo de `tienda-api`:

1. Imagen multi-stage de menos de 300 MB, non-root y con informe de escaneo revisado.
2. `compose.yaml` con redes separadas, healthchecks, límites y secretos fuera del repo.
3. Gates de usuario y tamaño ejecutados sobre la imagen final.
4. Pipeline que reproduce build, gates, escaneo y SBOM desde un push.

Se evalúa en una demo de 10 min por persona (o parejas si el grupo lo prefiere).


## Evaluación

| Componente | Peso |
|---|---|
| Labs de cada clase (4 entregables) | 40 % |
| Proyecto integrador + demo | 40 % |
| Participación y diagnóstico en clase | 20 % |

Aprobación: 70 %. Se evalúan el repositorio y la demo; no hay examen teórico.


## Infraestructura para 6 personas

- Cada participante: equipo con 8 GB RAM libres, Docker Engine 24+ y `kind` (o Docker Desktop con Kubernetes).
- Cada participante descarga las imágenes (`postgres`, `redis`, `alpine`, `netshoot`, `trivy`, `kindest/node`) antes de la sesión para no depender de su conexión.
- Cada participante necesita salida a Internet el día 1 para descargar imágenes, o un registro espejo local.
- Opcional: un host Linux compartido con Docker para demos de `macvlan` (requiere interfaz en la LAN).


## Cobertura del temario solicitado

| Tema del programa | Clase |
|---|---|
| Resumen de características y arquitectura | 1 |
| Configuración de Docker | 1 |
| Creación de imágenes propias | 1 |
| Aplicaciones multi-contenedor con Compose | 2 |
| Desafíos de implementar muchas aplicaciones | 3 |
| Orquestación de contenedores y control | 3 |
| Kubernetes en acción | 3 |
| Docker networking avanzado | 2 |
| Seguridad de Docker | 4 |
| Flujo de integración continua | 4 |
| Integración en un flujo de trabajo existente | 4 |
| Mejores prácticas de contenedores y orquestación | 4 (y transversal) |


## Materiales a preparar antes de impartir

- Repo plantilla con la app y un Dockerfile "ingenuo" de partida.
- Manifiestos K8s base (los alumnos completan probes y límites).
- Pipeline base con un paso vacío donde insertar build y scan.
- Checklist de hardening imprimible.
- Guion de demos de fallo: DNS roto, pod muerto, imagen con CVE, pipeline en rojo.
