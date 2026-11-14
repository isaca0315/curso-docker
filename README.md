# Curso de Docker Avanzado

Material del curso: 4 clases de 4 horas, 16 h en total, para 6 participantes.

Programa completo: [`curso-docker-avanzado.md`](curso-docker-avanzado.md)

## Clase 1: arquitectura, configuración y construcción de imágenes

| Material | Enlace |
|---|---|
| Guía paso a paso del lab | [`clase-01/lab/guia-paso-a-paso.md`](clase-01/lab/guia-paso-a-paso.md) |
| Aplicación de ejemplo | [`clase-01/lab/app/`](clase-01/lab/app/) |
| Diapositivas | [`clase-01/slides.md`](clase-01/slides.md) |
| Guía del instructor | [`clase-01/README.md`](clase-01/README.md) |
| Rúbrica del entregable | [`clase-01/evaluacion/rubrica-clase-01.md`](clase-01/evaluacion/rubrica-clase-01.md) |
| Checklist de Dockerfile | [`clase-01/recursos/checklist-dockerfile.md`](clase-01/recursos/checklist-dockerfile.md) |

Las clases 2 a 4 se añadirán a medida que se impartan.

## Requisitos

- Docker 24 o superior.
- Terminal en Linux, macOS o WSL2.
- 4 GB de disco libre para el lab de la clase 1.
- Git para clonar el repositorio.

## Cómo empezar

```bash
git clone git@github.com:isaca0315/curso-docker.git
cd curso-docker/clase-01/lab/app
docker run --rm hello-world
```

Después abre `clase-01/lab/guia-paso-a-paso.md` y sigue los pasos en orden.

## Estructura

```text
curso-docker/
├── curso-docker-avanzado.md    # programa de las 4 clases
└── clase-01/
    ├── README.md               # guía del instructor
    ├── slides.md               # diapositivas (Marp)
    ├── lab/
    │   ├── guia-paso-a-paso.md # guía del alumno
    │   └── app/                # tienda-api + Dockerfiles
    ├── demos/                  # demos de arquitectura, límites y caché
    ├── evaluacion/             # rúbrica
    └── recursos/               # checklist imprimible
```
