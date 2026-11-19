# Curso de Docker Avanzado

Material del curso: 4 clases de 4 horas, 16 h en total, para 6 participantes. Incluye un extra opcional de 40 min de Compose al final de la clase 1. Cada clase tiene una presentación en PowerPoint y una hora de contenido de reserva por si el grupo avanza rápido.

Programa completo: [`curso-docker-avanzado.md`](curso-docker-avanzado.md)

La misma aplicación, `tienda-api`, recorre las cuatro clases: se construye, se compone, se orquesta y se asegura.

## Clase 1: arquitectura, configuración y construcción de imágenes

| Material | Enlace |
|---|---|
| Guía paso a paso del lab | [`clase-01/lab/guia-paso-a-paso.md`](clase-01/lab/guia-paso-a-paso.md) |
| Aplicación de ejemplo | [`clase-01/lab/app/`](clase-01/lab/app/) |
| Diapositivas | [`clase-01/slides.md`](clase-01/slides.md) · [`slides.pptx`](clase-01/slides.pptx) |
| Guía del instructor | [`clase-01/README.md`](clase-01/README.md) |
| Guion de sesión del docente | [`clase-01/guia-docente.md`](clase-01/guia-docente.md) |
| Rúbrica del entregable | [`clase-01/evaluacion/rubrica-clase-01.md`](clase-01/evaluacion/rubrica-clase-01.md) |
| Checklist de Dockerfile | [`clase-01/recursos/checklist-dockerfile.md`](clase-01/recursos/checklist-dockerfile.md) |
| Extra de Compose (40 min) | [`clase-01/extra-compose/`](clase-01/extra-compose/README.md) |

## Clase 2: Compose y networking avanzado

| Material | Enlace |
|---|---|
| Guía paso a paso del lab | [`clase-02/lab/guia-paso-a-paso.md`](clase-02/lab/guia-paso-a-paso.md) |
| Stack de Compose | [`clase-02/lab/compose.yaml`](clase-02/lab/compose.yaml) |
| Aplicación y proxy | [`clase-02/lab/app/`](clase-02/lab/app/) · [`clase-02/lab/proxy/`](clase-02/lab/proxy/) |
| Diapositivas | [`clase-02/slides.md`](clase-02/slides.md) · [`slides.pptx`](clase-02/slides.pptx) |
| Guía del instructor | [`clase-02/README.md`](clase-02/README.md) |
| Guion de sesión del docente | [`clase-02/guia-docente.md`](clase-02/guia-docente.md) |
| Hora extra (3 bloques de 20 min) | [`clase-02/extra-60-min.md`](clase-02/extra-60-min.md) |
| Retos de diagnóstico | [`clase-02/lab/retos-diagnostico.md`](clase-02/lab/retos-diagnostico.md) |
| Rúbrica del entregable | [`clase-02/evaluacion/rubrica-clase-02.md`](clase-02/evaluacion/rubrica-clase-02.md) |
| Checklist de Compose | [`clase-02/recursos/checklist-compose.md`](clase-02/recursos/checklist-compose.md) |

## Clase 3: orquestación y Kubernetes con `kind`

| Material | Enlace |
|---|---|
| Guía paso a paso del lab | [`clase-03/lab/guia-paso-a-paso.md`](clase-03/lab/guia-paso-a-paso.md) |
| Manifiestos | [`clase-03/lab/manifests/`](clase-03/lab/manifests/) |
| Configuración del clúster | [`clase-03/lab/kind-config.yaml`](clase-03/lab/kind-config.yaml) |
| Diapositivas | [`clase-03/slides.md`](clase-03/slides.md) · [`slides.pptx`](clase-03/slides.pptx) |
| Guía del instructor | [`clase-03/README.md`](clase-03/README.md) |
| Guion de sesión del docente | [`clase-03/guia-docente.md`](clase-03/guia-docente.md) |
| Hora extra (3 bloques de 20 min) | [`clase-03/extra-60-min.md`](clase-03/extra-60-min.md) |
| Plan de día completo (8 h) | [`clase-03/plan-8h.md`](clase-03/plan-8h.md) |
| Laboratorio extra (60 min) | [`clase-03/lab/lab-3c.md`](clase-03/lab/lab-3c.md) |
| Laboratorio de Helm (60 min) | [`clase-03/lab/lab-3d.md`](clase-03/lab/lab-3d.md) |
| Laboratorio de StatefulSet (60 min) | [`clase-03/lab/lab-3e.md`](clase-03/lab/lab-3e.md) |
| Retos de diagnóstico | [`clase-03/lab/retos-diagnostico.md`](clase-03/lab/retos-diagnostico.md) |
| Rúbrica del entregable | [`clase-03/evaluacion/rubrica-clase-03.md`](clase-03/evaluacion/rubrica-clase-03.md) |
| Checklist de Kubernetes | [`clase-03/recursos/checklist-kubernetes.md`](clase-03/recursos/checklist-kubernetes.md) |

## Clase 4: caso de estudio, auditoría de `tienda-api` 4.0

| Material | Enlace |
|---|---|
| Guía paso a paso del lab | [`clase-04/lab/guia-paso-a-paso.md`](clase-04/lab/guia-paso-a-paso.md) |
| Stack endurecido | [`clase-04/lab/compose.yaml`](clase-04/lab/compose.yaml) |
| Imagen endurecida | [`clase-02/lab/app/Dockerfile.hardened`](clase-02/lab/app/Dockerfile.hardened) |
| Gates de CI | [`clase-04/lab/ci/verificar-imagen.sh`](clase-04/lab/ci/verificar-imagen.sh) |
| Workflow de ejemplo | [`clase-04/lab/ci/github-actions-ci.yml`](clase-04/lab/ci/github-actions-ci.yml) |
| Acta de salida | [`clase-04/lab/informes/acta-ejemplo.md`](clase-04/lab/informes/acta-ejemplo.md) |
| Diapositivas | [`clase-04/slides.md`](clase-04/slides.md) · [`slides.pptx`](clase-04/slides.pptx) |
| Guía del instructor | [`clase-04/README.md`](clase-04/README.md) |
| Guion de sesión del docente | [`clase-04/guia-docente.md`](clase-04/guia-docente.md) |
| Hora extra (3 bloques de 20 min) | [`clase-04/extra-60-min.md`](clase-04/extra-60-min.md) |
| Retos de auditoría | [`clase-04/lab/retos-auditoria.md`](clase-04/lab/retos-auditoria.md) |
| Rúbrica del entregable | [`clase-04/evaluacion/rubrica-clase-04.md`](clase-04/evaluacion/rubrica-clase-04.md) |
| Checklist de seguridad | [`clase-04/recursos/checklist-seguridad.md`](clase-04/recursos/checklist-seguridad.md) |

## Requisitos

- Docker Engine 24 o superior, o Docker Desktop 4.30 o superior.
- Docker Compose v2.24 o superior.
- Terminal en Linux, macOS o WSL2. En Windows, PowerShell también sirve: la guía de la clase 1 incluye un apéndice con las diferencias.
- 10 GB de disco libre para las cuatro clases.
- `kind` 0.24 o superior y `kubectl` 1.31 o superior para la clase 3.
- Helm 3.16 o superior solo para el plan de 8 horas de la clase 3.
- 8 GB de RAM en el equipo, con 2 GB libres para el clúster local. Con Docker Desktop, ajusta la memoria de la VM y sigue [`modo-bajo-consumo.md`](modo-bajo-consumo.md) si el mismo equipo hace la videollamada.
- Git para clonar el repositorio.

Trivy es opcional para la clase 4: el laboratorio funciona sin él y el escaneo se explica como informe.

## Cómo empezar

```bash
git clone git@github.com:isaca0315/curso-docker.git
cd curso-docker
docker run --rm hello-world
```

Cada clase tiene su propia guía. Empieza por `clase-01/lab/guia-paso-a-paso.md` y sigue el orden. Las clases 2, 3 y 4 reutilizan la aplicación de la clase 1 y 2; no hay que copiar código entre carpetas.

## Estructura

```text
curso-docker/
├── curso-docker-avanzado.md      # programa de las 4 clases
├── clase-01/
│   ├── README.md                 # guía del instructor
│   ├── guia-docente.md           # guion de sesión
│   ├── slides.md                 # diapositivas (Marp)
│   ├── slides.pptx               # presentación exportada
│   ├── lab/                      # guía del alumno + app + Dockerfiles
│   ├── demos/
│   ├── evaluacion/
│   └── recursos/
├── clase-02/
│   ├── lab/                      # compose, app con Postgres/Redis, proxy, guía
│   ├── demos/                    # redes, DNS roto, redes especiales
│   ├── evaluacion/
│   └── recursos/
├── clase-03/
│   ├── lab/                      # kind, manifiestos, guía
│   ├── demos/                    # auto-reparación, rollback, probes, workloads
│   ├── evaluacion/
│   └── recursos/
└── clase-04/
    ├── lab/                      # compose endurecido, gates, workflow, acta
    ├── demos/                    # runtime, escaneo, gates
    ├── evaluacion/
    └── recursos/
```
