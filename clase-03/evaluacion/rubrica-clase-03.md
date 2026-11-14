# Rúbrica: entregable de la clase 3

**Peso en el curso:** 10 % del total (los 4 entregables suman 40 %).
**Aprobación del entregable:** 70 / 100.
**Evidencia:** manifiestos en `lab/manifests/` + salidas de `kubectl` + demo de 3 minutos.

| Criterio | Peso | 4: Excelente | 3: Correcto | 2: Incompleto | 1: Insuficiente |
|---|---|---|---|---|---|
| Despliegue | 25 | Los cuatro pods `1/1`, PVC `Bound` y API en dos réplicas | Arranca con algún reintento | Falta un componente o hay que arreglarlo a mano | No arranca |
| Objetos y labels | 15 | Deployment, Service y selector coherentes; nombres claros | Correctos con algún detalle redundante | Service sin endpoints o selector roto | Objetos sueltos sin relación |
| Probes y recursos | 20 | Readiness y liveness con rutas distintas, requests y limits razonables | Probes presentes pero iguales o sin recursos | Solo una probe o sin recursos | Sin probes |
| Actualización y rollback | 20 | Rolling update con `maxUnavailable: 0` y `rollout undo` documentado | Actualiza y vuelve atrás con ayuda | Rollback falla o hay caída | No demuestra actualización |
| Ingress o acceso | 10 | Ingress por host o port-forward explicado; distingue 404 de 503 | Acceso funciona con pasos manuales | Acceso inestable | No accede |
| Explicación oral | 10 | Explica auto-reparación, Service y diferencia liveness/readiness | Responde con ayuda | Confunde Service con Ingress | No puede explicarlo |

## Checklist de evidencia

- [ ] `kubectl get nodes` muestra el nodo `Ready`.
- [ ] `kubectl get pods -n tienda` muestra `api` en dos réplicas `1/1`.
- [ ] `kubectl get pvc -n tienda` muestra `postgres-data` en `Bound`.
- [ ] `kubectl get endpoints api -n tienda` tiene dos IPs.
- [ ] `curl` a la API responde `{"db":"ok","redis":"ok"}`.
- [ ] `kubectl rollout history deployment/api -n tienda` tiene más de una revisión.
- [ ] `kubectl rollout undo` devuelve la versión anterior.
- [ ] Una prueba de readiness rota deja los pods `0/1` sin reiniciarlos.
- [ ] `kubectl get hpa -n tienda` muestra métricas o se explica por qué no hay `metrics-server`.

## Preguntas de la demo (3 min por alumno)

Se eligen al azar; se evalúa la explicación, no la memoria:

1. ¿Qué diferencia hay entre un pod y un Deployment?
2. ¿Cómo encuentra la API a Postgres sin configurar una IP?
3. ¿Qué pasa si un Service no tiene endpoints?
4. ¿Por qué la API no debería usar `/readyz` como liveness?
5. ¿Qué garantiza `maxUnavailable: 0` durante un rollout?
6. ¿Qué hace `kubectl rollout undo` y de dónde saca la revisión anterior?
7. ¿Qué diferencia hay entre un Ingress y un Service?
8. ¿Sobre qué valor calcula el HPA el porcentaje de CPU?
9. ¿Por qué `kind load docker-image` es necesario si la imagen ya está en Docker?
10. ¿Qué ventaja tiene `kind` frente a Docker Desktop Kubernetes para este lab?

## Nota sobre el alcance

El laboratorio usa un clúster de un solo nodo. No se evalúan alta disponibilidad del control plane, StorageClasses reales ni políticas de red del CNI. Se explican en la puesta en común porque el programa pide conocer el ecosistema, pero un clúster multi-nodo no cabe en 4 horas ni en la memoria de un portátil de aula.
