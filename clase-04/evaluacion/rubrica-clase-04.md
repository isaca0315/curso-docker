# Rúbrica: entregable de la clase 4

**Peso en el curso:** 10 % del total (los 4 entregables suman 40 %).
**Aprobación del entregable:** 70 / 100.
**Evidencia:** `lab/informes/acta.md` + stack endurecido + salida de gates + informe de Trivy o `lab/informes/README.md` + SBOM + demo de 3 minutos.

El caso de estudio se evalúa sobre los cuatro hallazgos del auditor. Cada criterio se demuestra con un comando o con una línea del acta. En los casos alternativos de `casos/`, se sustituye el acta de salida por el informe postmortem o por el acta de publicación; los criterios técnicos no cambian.

| Criterio | Peso | 4: Excelente | 3: Correcto | 2: Incompleto | 1: Insuficiente |
|---|---|---|---|---|---|
| Imagen sin privilegios (H1) | 25 | UID fijo, sin shell de login y sin pip en runtime; el gate lo demuestra | Usuario no root, con algún resto innecesario | Usuario declarado pero el proceso arranca como root | Root |
| Runtime restringido (H3) | 20 | Solo lectura, `cap_drop: ALL`, `no-new-privileges`, `/tmp` acotado y límites; explica el caso de Redis | La mayoría de controles, con uno ausente | Solo uno o dos controles | Sin controles |
| Red y secretos (H2) | 15 | Base interna, API como único puente, contraseña fuera de la imagen y `docker history` limpio | Red separada, secreto en variable | Una red o secreto versionado | Expone la base y la contraseña |
| Gates y decisión de publicación (H4) | 20 | Gates deterministas en verde y en rojo, SBOM, lectura por capas de los CVEs y decisión justificada en el acta | Gates presentes pero sin probar el fallo o acta incompleta | Script que solo imprime información | Sin gates y sin criterio de publicación |
| Auditoría cruzada y demo | 10 | Explica un hallazgo ajeno con su control y responde en la demo las tres preguntas | Responde dos de tres | Responde una | No participa |

## Preguntas de la demo (3 minutos)

1. ¿Qué control se arregla en la imagen y cuál solo en ejecución?
2. ¿Por qué Redis necesita un usuario explícito con `cap_drop: ALL`?
3. ¿Por qué el gate no es la lista de CVEs del día?

## Cierre de la clase

1. ¿Qué control añadirías después de este curso en un entorno de producción?
2. ¿Qué cambia en la cadena de suministro cuando publicas por digest y no por `latest`?

## Límite del laboratorio

El laboratorio no firma imágenes ni configura políticas de admisión. Se explican en clase porque completan la cadena de suministro, pero requieren registry, `cosign` y un clúster con webhook de admisión. El entregable se centra en lo que se puede construir y verificar con Docker y Compose en el equipo de cada participante.
