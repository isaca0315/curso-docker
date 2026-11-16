# Lab 2: índice

Práctica de la clase 2: levantar `tienda-api` con Postgres, Redis y Nginx usando Compose, separar redes y diagnosticar fallos de DNS y conectividad.

## Empieza aquí

**[Guía paso a paso](guia-paso-a-paso.md)**

Cada paso indica el objetivo, el comando, el resultado esperado y qué comprobar antes de seguir. Incluye una guía de diagnóstico y una chuleta.

## Material de apoyo

| Archivo | Contenido |
|---|---|
| [`guia-paso-a-paso.md`](guia-paso-a-paso.md) | Guía completa (pasos 0-8) |
| [`retos-diagnostico.md`](retos-diagnostico.md) | Cuatro averías cronometradas para el bloque de cierre |
| [`compose.yaml`](compose.yaml) | Stack base: API, Postgres, Redis, Nginx, redes y secreto |
| [`compose.override.yaml`](compose.override.yaml) | Modo desarrollo: puerto 18011, recarga y watch |
| [`app/`](app/) | Código de la API y su Dockerfile multi-stage |
| [`proxy/nginx.conf`](proxy/nginx.conf) | Proxy inverso hacia `api:8000` |
| [`secrets/db_password.txt.example`](secrets/db_password.txt.example) | Plantilla del secreto; el archivo real no se versiona |
| [`../demos/`](../demos/) | Demos de redes, DNS roto y redes especiales |
| [`../evaluacion/rubrica-clase-02.md`](../evaluacion/rubrica-clase-02.md) | Cómo se evalúa el entregable |

## Antes de empezar

```bash
cp secrets/db_password.txt.example secrets/db_password.txt
docker compose config --quiet
docker compose up -d --build
```

El stack tarda menos de un minuto si las imágenes ya están descargadas. Los servicios quedan sanos en este orden: `db` y `redis`, luego `api`, luego `proxy`.

## Puertos

| Servicio | Puerto en el host |
|---|---|
| Proxy (Nginx) | 18010 |
| API en modo desarrollo | 18011 |
| Adminer (profile `tools`) | 18012 |

Si algún puerto está ocupado, cambia solo el número de la izquierda.
