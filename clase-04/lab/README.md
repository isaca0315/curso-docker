# Lab 4: índice

Práctica de la clase 4: construir una imagen de `tienda-api` sin privilegios, ejecutarla con el runtime restringido y poner gates en un pipeline de CI.

## Empieza aquí

**[Guía paso a paso](guia-paso-a-paso.md)**

La guía incluye resultados medidos, el fallo de Redis con `cap_drop` y las decisiones del pipeline.

## Material de apoyo

| Archivo | Contenido |
|---|---|
| [`guia-paso-a-paso.md`](guia-paso-a-paso.md) | Guía completa (pasos 0-8) |
| [`retos-auditoria.md`](retos-auditoria.md) | Cuatro comprobaciones de auditoría para el bloque de cierre |
| [`compose.yaml`](compose.yaml) | Stack con `read_only`, `cap_drop`, `no-new-privileges` y red interna |
| [`ci/verificar-imagen.sh`](ci/verificar-imagen.sh) | Gates de usuario y tamaño, Trivy opcional |
| [`ci/github-actions-ci.yml`](ci/github-actions-ci.yml) | Ejemplo de workflow para copiar a `.github/workflows/` |
| [`k8s/`](k8s/) | Overlay de Kustomize sobre los manifiestos de la clase 3 |
| [`secrets/db_password.txt.example`](secrets/db_password.txt.example) | Plantilla del secreto; el archivo real no se versiona |
| [`../demos/01-runtime-endurecido.sh`](../demos/01-runtime-endurecido.sh) | Usuario, solo lectura, capacidades y redes |
| [`../demos/02-escaneo-trivy.sh`](../demos/02-escaneo-trivy.sh) | CVEs y SBOM |
| [`../demos/03-gates-ci.sh`](../demos/03-gates-ci.sh) | Gates en verde y en rojo |
| [`../evaluacion/rubrica-clase-04.md`](../evaluacion/rubrica-clase-04.md) | Cómo se evalúa el entregable |

La aplicación es la misma de la clase 2. El Dockerfile endurecido está en [`../../clase-02/lab/app/Dockerfile.hardened`](../../clase-02/lab/app/Dockerfile.hardened).

## Antes de empezar

```bash
cp secrets/db_password.txt.example secrets/db_password.txt
docker compose build api
docker compose up -d
./ci/verificar-imagen.sh tienda-api:4.0
curl -s localhost:18030/
```

## Puertos

| Servicio | Puerto en el host |
|---|---|
| API | 18030 |
| Postgres | sin publicar |
| Redis | sin publicar |

## Limpieza

```bash
docker compose down -v
docker rmi tienda-api:4.0 2>/dev/null || true
```
