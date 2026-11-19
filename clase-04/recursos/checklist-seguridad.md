# Checklist de seguridad

Úsalo antes de entregar el lab 4. Cada casilla debe poder demostrarse con un comando.

## Imagen

- [ ] La imagen declara un usuario distinto de root.
- [ ] El proceso arranca con un UID sin privilegios.
- [ ] El usuario no tiene shell de login y no se crea su directorio home.
- [ ] El código se copia con `--chown`.
- [ ] pip y las herramientas de build no están en la etapa final.
- [ ] Las dependencias tienen versión fija.
- [ ] La imagen tiene etiquetas OCI y versión.
- [ ] El tamaño es razonable para la base elegida.

## Secretos

- [ ] La contraseña no está en el Dockerfile.
- [ ] La contraseña no está en una variable de entorno del build.
- [ ] El secreto se monta en ejecución.
- [ ] El archivo del secreto está en `.gitignore`.
- [ ] `docker history` no muestra la contraseña.

## Runtime

- [ ] `read_only: true` y `tmpfs` en `/tmp`.
- [ ] `cap_drop: ALL`.
- [ ] `no-new-privileges:true`.
- [ ] El proceso funciona sin escribir en `/app`.
- [ ] Cada servicio tiene límites de CPU y memoria.
- [ ] La base y Redis no están en la red pública.
- [ ] Un contenedor solo en red `internal` no publica puertos.

## Pipeline

- [ ] El build usa el Dockerfile endurecido.
- [ ] El gate de usuario falla con una imagen root.
- [ ] El gate de tamaño falla con un límite bajo.
- [ ] El workflow declara permisos mínimos.
- [ ] Las credenciales van en `secrets`.
- [ ] El SARIF tiene `security-events: write`.
- [ ] La publicación usa versión y digest.

## Escaneo

- [ ] Trivy está ejecutado o se explica por qué no.
- [ ] Sabes cuántos CVEs hay por severidad.
- [ ] Distingues base, dependencia y unfixed.
- [ ] Hay un SBOM generado.
- [ ] La decisión sobre qué hacer con los CVEs está escrita.

## Acta de salida

- [ ] Los cuatro hallazgos del auditor están marcados como abiertos o cerrados.
- [ ] Cada hallazgo tiene un comando y su salida real.
- [ ] La decisión de publicar está justificada con la evidencia.
