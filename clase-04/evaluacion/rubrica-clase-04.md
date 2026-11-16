# Rúbrica: entregable de la clase 4

**Peso en el curso:** 10 % del total (los 4 entregables suman 40 %).
**Aprobación del entregable:** 70 / 100.
**Evidencia:** `compose.yaml` endurecido + salida de gates + informe de Trivy y SBOM + demo de 3 minutos.

| Criterio | Peso | 4: Excelente | 3: Correcto | 2: Incompleto | 1: Insuficiente |
|---|---|---|---|---|---|
| Imagen sin privilegios | 25 | UID fijo, sin shell de login y sin pip en runtime; el gate lo demuestra | Usuario no root, con algún resto innecesario | Usuario declarado pero el proceso arranca como root | Root |
| Runtime restringido | 20 | Solo lectura, `cap_drop: ALL`, `no-new-privileges` y `/tmp` acotado | La mayoría de controles, con uno ausente | Solo uno o dos controles | Sin controles |
| Red y secretos | 15 | Base interna, API como único puente y contraseña fuera de la imagen | Red separada, secreto en variable | Una red o secreto versionado | Expone la base y la contraseña |
| Gates de CI | 20 | Gates deterministas de usuario y tamaño, con caso de fallo documentado | Gates presentes pero sin probar el fallo | Script que solo imprime información | No hay gates |
| Escaneo y SBOM | 10 | Informe leído, SBOM generado y decisión justificada | Informe generado sin interpretación | Solo ejecuta la herramienta | No lo hace |
| Explicación oral | 10 | Explica un control de imagen, uno de runtime y por qué el gate no es el escaneo | Responde con ayuda | Confunde imagen con runtime | No puede explicarlo |

## Checklist de evidencia

- [ ] `docker compose config --quiet` termina sin errores.
- [ ] `docker compose ps` muestra la API, Postgres y Redis en `healthy`.
- [ ] `docker image inspect tienda-api:4.0` declara `10001:10001`.
- [ ] `docker run --rm --entrypoint python tienda-api:4.0 -c 'import os; print(os.getuid())'` devuelve 10001.
- [ ] `docker compose exec -T api sh -c 'touch /app/x'` falla por solo lectura.
- [ ] `CapEff` es `0000000000000000`.
- [ ] `./ci/verificar-imagen.sh tienda-api:4.0` termina en verde.
- [ ] El gate falla con `python:3.12-slim` y con `MAX_MB=50`.
- [ ] Hay un informe de Trivy y un SBOM generado.
- [ ] `secrets/db_password.txt` no está en `git status`.

## Preguntas de la demo (3 min por alumno)

Se eligen al azar; se evalúa la explicación, no la memoria:

1. ¿Qué diferencia hay entre un CVE de la base y uno de una dependencia de Python?
2. ¿Por qué la contraseña no puede ir en un `ARG`?
3. ¿Qué impide `read_only: true` que no impide `USER`?
4. ¿Por qué Redis necesita un usuario explícito si se quitan las capacidades?
5. ¿Qué hace `no-new-privileges` y qué ataque bloquea?
6. ¿Por qué el gate de tamaño no depende de la base de CVEs?
7. ¿Cuándo convertirías Trivy en un gate que falla el pipeline?
8. ¿Para qué sirve un SBOM si ya escaneas la imagen?
9. ¿Qué ventaja tiene desplegar por digest en lugar de por etiqueta?
10. ¿Qué control añadirías después de este curso en un clúster de producción?

## Nota sobre el alcance

El laboratorio no firma imágenes ni configura políticas de admisión. Se explican en la clase porque completan la cadena de suministro, pero requieren un registry, `cosign` y un clúster con un webhook de admisión. El entregable se centra en lo que se puede construir y verificar en un equipo.
