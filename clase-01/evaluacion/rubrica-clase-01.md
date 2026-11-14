# Rúbrica: entregable de la clase 1

**Peso en el curso:** 10 % del total (los 4 entregables suman 40 %).
**Aprobación del entregable:** 70 / 100.
**Evidencia:** `Dockerfile` + informe de 5 líneas + demo de 2 minutos.

| Criterio | Peso | 4: Excelente | 3: Correcto | 2: Incompleto | 1: Insuficiente |
|---|---|---|---|---|---|
| Funcionalidad | 25 | La app responde `/`, `/productos` y `/healthz`; el healthcheck pasa a `healthy` | Responde los 3 endpoints, healthcheck tarda o no está | Falla algún endpoint o el contenedor no arranca sin explicación | No ejecuta |
| Multi-stage | 20 | Builder, test y runtime separados; la etapa de test bloquea el build; la imagen final solo lleva runtime, dependencias y código | Builder y runtime separados, sin etapa de test o con copias de más | Etapas mal separadas o sin multi-stage | Todo en una etapa |
| Seguridad básica | 20 | Usuario no root con UID fijo, versiones fijadas, sin secretos, `--no-cache-dir` | No root y versiones fijadas, algún detalle menor | Root o `latest`, sin justificación | Root y secretos/versiones flotantes |
| Tamaño | 15 | ≤ 100 MB (reto) | ≤ 250 MB | ≤ 600 MB | > 600 MB |
| Caché y orden | 10 | Dependencias antes que código; explica qué capa se invalida al cambiar `app.py` | Orden correcto, explicación parcial | Orden incorrecto, entiende el concepto | No lo entiende |
| Informe y demo | 10 | Informe completo con mediciones reales y una decisión justificada; explica con claridad | Informe completo | Faltan datos o la explicación es superficial | Sin informe |

## Checklist de evidencia

- [ ] `docker build` termina sin errores desde un contexto limpio.
- [ ] Si se rompe un endpoint, el build falla en la etapa de test.
- [ ] `docker run` levanta la app y los tres endpoints responden.
- [ ] `docker exec <contenedor> id` muestra un UID distinto de 0.
- [ ] `docker images` muestra el tamaño final y coincide con el informe.
- [ ] El `Dockerfile` usa una base fijada (no `latest`).
- [ ] Existe `.dockerignore`.
- [ ] El informe incluye tamaños naive/optimizada/reto y una decisión justificada.
- [ ] Si usó distroless, la imagen responde y explica cómo verificó el usuario sin `id` ni shell.

## Preguntas de la demo (2 min por alumno)

Se eligen al azar; se evalúa la explicación, no la memoria:

1. ¿Dónde vive el kernel del contenedor?
2. ¿Qué diferencia hay entre un namespace y un cgroup?
3. ¿Por qué el contenedor no ve los procesos del host?
4. ¿Qué capa se invalida si cambio `requirements.txt`? ¿Y si cambio `app.py`?
5. ¿Por qué `USER appuser` importa si el contenedor ya está aislado?
6. ¿Qué pasa si quito `--memory` en un host de producción?
7. ¿Qué trade-off tiene `alpine` frente a `slim`?
8. ¿Por qué no se deben pasar secretos por `ENV`?
9. ¿Qué pierdes al usar una imagen distroless y cómo lo compensas?

## Nota sobre el reto

El límite de 100 MB sirve para practicar; un caso real puede justificar otra cifra. Un alumno que se quede en 120 MB pero explique con precisión el trade-off de `musl`, la superficie de ataque y qué sacrifica, puede obtener 4 en "Tamaño" si el resto es sólido. No se acepta una imagen pequeña que no funciona ni un `Dockerfile` que el alumno no sepa explicar.
