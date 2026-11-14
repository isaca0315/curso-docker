# Lab 1: índice

Práctica de la clase 1: construir `tienda-api`, medirla, optimizarla y reducirla de **1,63 GB a 79 MB**.

## Empieza aquí

**[Guía paso a paso](guia-paso-a-paso.md)**

Cada paso indica el objetivo del comando, el resultado esperado y qué hacer si falla. Incluye checkpoints, solución de problemas y apéndices.

## Material de apoyo

| Archivo | Contenido |
|---|---|
| [`guia-paso-a-paso.md`](guia-paso-a-paso.md) | Guía completa del laboratorio (pasos 0-8) |
| [`app/README.md`](app/README.md) | Qué es `tienda-api`, endpoints, variables y los tres Dockerfiles |
| [`app/Dockerfile.naive`](app/Dockerfile.naive) | Imagen de partida con anti-patrones (1,63 GB) |
| [`app/Dockerfile`](app/Dockerfile) | Solución multi-stage de referencia (205 MB) |
| [`app/Dockerfile.alpine`](app/Dockerfile.alpine) | Solución del reto < 100 MB (79 MB) |
| [`../evaluacion/rubrica-clase-01.md`](../evaluacion/rubrica-clase-01.md) | Cómo se evalúa el entregable |
| [`../recursos/checklist-dockerfile.md`](../recursos/checklist-dockerfile.md) | Checklist imprimible de buenas prácticas |

## Resultados esperados

| Medición | Naive | Optimizada | Alpine (reto) |
|---|---|---|---|
| Tamaño | 1,63 GB | 205 MB | 78,7 MB |
| Usuario | root | 10001 | 10001 |
| Multi-stage | No | Sí | Sí |
| Endpoints | 3/3 | 3/3 | 3/3 |

## Antes de empezar

- Docker 24 o superior (Engine o Desktop) funcionando (`docker run --rm hello-world`).
- 4 GB de disco libre (la primera descarga de `python:3.12` ronda 1 GB).
- Terminal en `clase-01/lab/app`.
- Puertos 18000, 18001 y 18002 libres; si no, usa otros y ajusta `-p`.

## Entregable

`Dockerfile` multi-stage funcionando + informe de 5 líneas con tamaños, usuarios, tiempos y una decisión justificada. Detalle en el paso 8 de la guía.

## Para el instructor

- Tiempo: 60 min para los pasos 1-6 y 35 min para reto + entregable.
- Los alumnos deben intentar el `Dockerfile` antes de abrir la solución; la guía lo indica.
- La caché se demuestra cambiando el contenido de `app.py`, porque BuildKit indexa contenido y `touch` no basta.
- El OOM necesita tocar las páginas de memoria; el comando de la guía ya lo hace.
- Si alguien se atasca más de 5 minutos, desbloquéalo con la tabla de solución de problemas; no dejes que el lab se convierta en una clase de debugging.
