# Informes guardados

Carpeta para la salida de Trivy y el SBOM que se comparten si falla la conexión o Trivy no está disponible.

El día anterior, con Trivy instalado y la imagen construida:

```bash
cd clase-04/lab
trivy image --format table -o informes/trivy-tienda-api-4.0.txt tienda-api:4.0
trivy image --format cyclonedx -o informes/sbom-tienda-api-4.0.cdx.json tienda-api:4.0
```

Si Trivy no está instalado, sirve la imagen oficial:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD/informes:/informes" aquasec/trivy:latest image \
  --format table -o /informes/trivy-tienda-api-4.0.txt tienda-api:4.0
```

Los informes llevan la fecha del escaneo. No los uses como prueba de que la imagen sigue limpia: vuelve a escanear cuando cambie la base o las dependencias.
