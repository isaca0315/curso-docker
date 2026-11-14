# Rúbrica: entregable de la clase 2

**Peso en el curso:** 10 % del total (los 4 entregables suman 40 %).
**Aprobación del entregable:** 70 / 100.
**Evidencia:** `compose.yaml` + guía de diagnóstico de 10 líneas + demo de 3 minutos.

| Criterio | Peso | 4: Excelente | 3: Correcto | 2: Incompleto | 1: Insuficiente |
|---|---|---|---|---|---|
| Stack funcional | 25 | Los cuatro servicios arrancan sanos con `docker compose up -d --build` | Arranca con algún reintento o aviso menor | Algún servicio falla o hay que arreglarlo a mano | No arranca |
| Orden y salud | 15 | `depends_on` con `service_healthy` y healthchecks reales | Healthchecks presentes, orden parcial | Solo `depends_on` simple o sin healthchecks | Arranca todo a la vez |
| Aislamiento de red | 20 | `frontend` y `backend` separadas; `backend` interna; la base no es alcanzable desde el proxy | Redes separadas sin `internal` o con un servicio mal colocado | Una sola red para todo | No demuestra aislamiento |
| Volúmenes y secretos | 15 | Datos persistentes; contraseña en archivo fuera del repo | Persistencia correcta, secreto en variable de entorno | Sin persistencia o secreto versionado | Pierde datos y expone la contraseña |
| Guía de diagnóstico | 15 | Orden claro, comandos ejecutables, distingue DNS de puerto | Completa pero genérica | Lista de comandos sin criterio | No entrega |
| Explicación oral | 10 | Explica `localhost`, DNS embebido y por qué el proxy no va en `backend` | Responde con ayuda | Confunde DNS con puerto | No puede explicarlo |

## Checklist de evidencia

- [ ] `docker compose config --quiet` termina sin errores.
- [ ] `docker compose ps` muestra `db`, `redis`, `api` y `proxy` en `healthy`.
- [ ] `curl localhost:18010/readyz` responde `ready`.
- [ ] `docker network inspect tienda_backend` incluye `db`, `redis` y `api`.
- [ ] `docker network inspect tienda_frontend` incluye `api` y `proxy`.
- [ ] `db` no resuelve desde el contenedor del proxy.
- [ ] `docker compose down` conserva los datos y `down -v` los borra.
- [ ] `secrets/db_password.txt` no está en `git status`.

## Preguntas de la demo (3 min por alumno)

Se eligen al azar; se evalúa la explicación, no la memoria:

1. ¿Por qué la API está en las dos redes y el proxy en una sola?
2. ¿Qué hace `internal: true` y qué servicio lo necesita?
3. ¿Qué diferencia hay entre un error de DNS y un `Connection refused`?
4. ¿Por qué `localhost:5432` falla dentro de la API?
5. ¿Qué cambia entre `docker compose down` y `down -v`?
6. ¿Para qué sirve `condition: service_healthy`?
7. ¿Cuándo usarías un profile y cuándo un override?
8. ¿Qué riesgo tiene `--network host`?

## Nota sobre el alcance

El lab no exige `macvlan` ni `overlay`. Se explican en la demo y en la puesta en común porque el programa pide conocerlos, pero evaluarlos requeriría una LAN controlada y varios hosts. Quien los pruebe por su cuenta puede sumar en "Explicación oral" si describe bien las limitaciones.
