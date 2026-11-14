# Checklist de Kubernetes

Úsalo antes de entregar el lab 3. Cada casilla debe poder demostrarse con un comando.

## Clúster

- [ ] `kind get clusters` muestra `curso`.
- [ ] `kubectl get nodes` muestra el nodo en `Ready`.
- [ ] El contexto actual es `kind-curso`.
- [ ] Los pods de `kube-system` están `Running`.

## Imagen

- [ ] `docker image inspect tienda-api:3.0` funciona.
- [ ] `kind load docker-image tienda-api:3.0 --name curso` terminó sin error.
- [ ] `docker exec curso-control-plane crictl images` muestra la imagen.
- [ ] La etiqueta del manifiesto coincide con la imagen cargada.

## Manifiestos

- [ ] Namespace `tienda` creado.
- [ ] Secret referenciado por Postgres y por la API.
- [ ] PVC de Postgres en `Bound`.
- [ ] Deployment y Service para `db`, `redis` y `api`.
- [ ] Selector del Service coincide con las labels del pod.
- [ ] Imágenes con versión fija, no `latest`.

## Salud y recursos

- [ ] `readinessProbe` consulta `/readyz`.
- [ ] `livenessProbe` consulta `/healthz`.
- [ ] `initialDelaySeconds` da tiempo al arranque.
- [ ] Cada contenedor tiene `requests` y `limits`.
- [ ] La API declara `runAsNonRoot`.

## Operación

- [ ] Borrar un pod de la API produce otro.
- [ ] `kubectl scale` cambia pods y endpoints.
- [ ] `kubectl rollout history` muestra las revisiones.
- [ ] `kubectl rollout undo` vuelve a la anterior.
- [ ] Una readiness rota deja pods `0/1` fuera de los endpoints.
- [ ] Sabes leer `kubectl describe pod` y `kubectl get events`.

## Acceso

- [ ] `kubectl port-forward svc/api 18013:8000` responde.
- [ ] El Ingress responde con `Host: tienda.local` en el puerto 18020.
- [ ] Distingues un 404 de host de un 503 sin endpoints.
- [ ] Sabes por qué el Ingress necesita `extraPortMappings` en `kind`.

## Escalado

- [ ] `kubectl top pods -n tienda` devuelve valores.
- [ ] El HPA muestra el objetivo y el uso actual.
- [ ] Bajo carga, el número de réplicas sube.
- [ ] Al quitar la carga, baja tras la ventana de estabilización.
