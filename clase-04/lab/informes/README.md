# Informes de respaldo

Aquí se guarda la evidencia cuando Trivy no está disponible o la descarga de la base falla durante la clase. El laboratorio no depende de estos archivos: con Trivy instalado, genera el informe y el SBOM en local.

## Informe de escaneo de referencia

Imagen: `tienda-api:4.0`, construida desde `clase-02/lab/app/Dockerfile.hardened` con base `python:3.12-slim`.

```text
python:3.12-slim (Debian bookworm)
CRITICAL: 0 con corrección disponible
HIGH:     2 en zlib1g, ambas con versión corregida en la base Debian
```

Los números son de la fecha en que se preparó el material. Un escaneo posterior puede dar otro resultado sin que el equipo haya cambiado la imagen. Por eso el gate principal del pipeline es el usuario y el tamaño, no la lista de CVEs del día.

Cómo leer el resultado:

- CVE en `debian`: se corrige actualizando la imagen base y reconstruyendo.
- CVE en `python-pkg`: se corrige subiendo la versión en `requirements.txt`.
- CVE `unfixed`: no se arregla con un rebuild. Se mitiga con runtime endurecido y red restringida, o se acepta por escrito con fecha y responsable.

## SBOM de referencia

El SBOM se genera en CycloneDX con:

```bash
trivy image --format cyclonedx --output /tmp/tienda-api-sbom.json tienda-api:4.0
du -h /tmp/tienda-api-sbom.json
```

Tamaño esperado: unos 200 KB. Contiene las dependencias del sistema y de Python con sus versiones. No se guarda aquí porque cambia con cada reconstrucción de la base.

## Plantilla del acta

[`acta-ejemplo.md`](acta-ejemplo.md) es la plantilla del entregable. Cada pareja la copia a `acta.md` y la rellena con sus propias salidas.
