# Clase 2: Compose y networking avanzado

**Duración:** 4 h · **Participantes:** 6 · **Requisitos:** Docker Engine 24+ o Docker Desktop 4.30+, Docker Compose v2.24+

## Materiales

| Archivo | Para qué |
|---|---|
| `slides.md` | Diapositivas (Marp). Renderizar con `marp slides.md -o slides.pdf` o proyectar el Markdown |
| `slides.pptx` | Presentación lista para proyectar (exportada de `slides.md`) |
| `extra-60-min.md` | Reserva: DNS a fondo, tcpdump y anclas YAML (3 bloques de 20 min) |
| `guia-docente.md` | Guion de sesión: preparación, tiempos, checkpoints y planes de contingencia |
| `lab/guia-paso-a-paso.md` | Guía del alumno con resultados esperados y diagnóstico |
| `lab/lab-2c.md` | Lab opcional de 60 min: override, copia de seguridad y redes a mano |
| `lab/retos-diagnostico.md` | Cuatro averías cronometradas para el bloque de cierre |
| `lab/compose.yaml` | Stack base: API, Postgres, Redis, Nginx, redes y secreto |
| `lab/compose.override.yaml` | Modo desarrollo con recarga y `docker compose watch` |
| `lab/app/` | Código y Dockerfile de la API con Postgres y Redis |
| `lab/proxy/nginx.conf` | Proxy inverso |
| `demos/01-redes.sh` | Aislamiento, DNS y puertos en vivo |
| `demos/02-dns-roto.sh` | Nombre inexistente y `localhost` dentro del contenedor |
| `demos/03-redes-especiales.md` | `host`, `none`, `macvlan` y `overlay` |
| `evaluacion/rubrica-clase-02.md` | Rúbrica del entregable |
| `recursos/checklist-compose.md` | Checklist imprimible |

## Cómo usar este material

**Instructor**

1. Ejecuta `docker compose up -d --build` en `lab/` antes de clase y comprueba los cuatro servicios sanos.
2. Pre-descarga las imágenes de la sección "Preparación del aula".
3. Proyecta `slides.pptx` y sigue `guia-docente.md` para los tiempos, los checkpoints y los planes B.
4. Ten a mano la guía de diagnóstico: es el entregable principal de la clase.
5. Usa `lab/retos-diagnostico.md` en el bloque de cierre: los cuatro retos son parte del plan. Solo si surge una emergencia de tiempo, haz los retos 1 y 3 y deja el resto para casa.
6. Si el grupo termina antes, `lab/lab-2c.md` tiene un laboratorio de 60 min de operación del stack y `extra-60-min.md` tres bloques de temas nuevos: DNS, tcpdump y anclas YAML.
7. La demo de `macvlan` solo funciona en un host Linux con interfaz en la LAN. Si los participantes usan laptops, explícala con la pantalla compartida; no la asignes como obligatoria.

**Alumno**

1. Sigue `lab/guia-paso-a-paso.md` en orden.
2. No avances del paso 4 sin saber qué contenedores hay en cada red.
3. Usa `recursos/checklist-compose.md` antes de entregar.

## Agenda (240 min)

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:15 | Repaso y dudas de la clase 1 | `docker images`, preguntas del lab 1 |
| 00:15-00:55 | Compose: servicios, redes, volúmenes, secretos, `depends_on`, profiles, override, watch | `slides.md` |
| 00:55-01:50 | Lab 2a: stack completo, orden de arranque, redes separadas, persistencia | `lab/guia-paso-a-paso.md` pasos 0-3 |
| 01:50-02:00 | Pausa | sin material |
| 02:00-02:40 | Networking: bridge, user-defined, DNS, `host`, `none`, `macvlan`, `overlay`, iptables, `netshoot` | `slides.md` + `demos/01-redes.sh` |
| 02:40-03:25 | Lab 2b: aislamiento, DNS roto, captura con `netshoot`, `host` vs bridge, `macvlan` opcional | `lab/guia-paso-a-paso.md` pasos 4-6 + `demos/02-dns-roto.sh` |
| 03:25-03:50 | Retos de diagnóstico en parejas | `lab/retos-diagnostico.md` |
| 03:50-04:00 | Entregable, dudas y cierre | `lab/guia-paso-a-paso.md` paso 8 |

El paso 7 (override, watch y Adminer) se explica en la teoría y queda como extensión para quien termine antes o como deberes.

Si sobra una hora, `lab/lab-2c.md` junta el paso 7, la copia de seguridad de Postgres y las redes a mano en un laboratorio de 60 min. No ocupa un hueco en la agenda de 240 min; se usa como reserva.

## Conceptos clave

- **Compose describe el estado final.** Los servicios, redes y volúmenes se crean a partir del YAML; no hay pasos imperativos.
- **Red por defecto contra red propia.** La red `bridge` por defecto no tiene DNS por nombre. Una red user-defined sí.
- **Aislamiento por pertenencia.** Un contenedor solo alcanza a los servicios de sus redes. No hay firewall que configurar.
- **Healthcheck y `depends_on`.** `condition: service_healthy` convierte la salud en una dependencia real.
- **Secretos como archivo.** La contraseña se monta en `/run/secrets`; no viaja en la imagen ni en las variables de entorno.
- **Override por entorno.** `compose.override.yaml` se carga solo; el compose base queda para el despliegue.
- **`localhost` es local al contenedor.** Entre servicios se usa el nombre del servicio.

## Guion de demos

1. **Redes** (`demos/01-redes.sh`): mostrar la red interna, resolver `db` desde la API, fallar desde el proxy y comparar `localhost` con `db`. Preguntar: *¿qué red necesita el proxy?*
2. **DNS roto** (`demos/02-dns-roto.sh`): un nombre inexistente devuelve `Name or service not known`; `localhost:5432` devuelve `Connection refused`. Preguntar: *¿cuál de los dos errores es DNS y cuál es de puerto?*
3. **Redes especiales** (`demos/03-redes-especiales.md`): `--network host` comparte la pila del host; `--network none` deja solo loopback; `macvlan` da una IP de la LAN. Preguntar: *¿qué pierdes con `host`?*

## Errores comunes y cómo resolverlos

| Síntoma | Causa | Solución |
|---|---|---|
| La API reinicia en bucle | Postgres no está listo o falta el secreto | `docker compose logs api`; revisar `depends_on` y `/run/secrets/db_password` |
| `password authentication failed` | Volumen con la contraseña vieja | `docker compose down -v` y volver a arrancar |
| Nginx devuelve 502 | La API no está sana | `docker compose ps`; `docker compose logs api` |
| `db` no resuelve desde el proxy | El proxy no está en `backend` | Es lo esperado: el proxy solo habla con la API |
| `depends_on` no espera | Falta `condition: service_healthy` | Añadirlo y comprobar que el healthcheck existe |
| Cambios de código no aparecen | Se arrancó con `-f compose.yaml` o sin watch | `docker compose up -d` sin `-f` y `docker compose watch` |
| Adminer no abre | Falta el profile | `docker compose --profile tools up -d` |
| `macvlan` sin conectividad | La interfaz no está en la LAN o el switch filtra MAC | Probar en un host Linux conectado por cable |

## Evaluación

- Entregable: `compose.yaml` que arranca sano, captura de las dos redes y guía de diagnóstico de 10 líneas.
- Rúbrica: `evaluacion/rubrica-clase-02.md` (10 % del curso).
- Demo oral (3 min): explicar el aislamiento, el orden de arranque y un fallo de DNS real.

## Preparación del aula

```bash
docker pull postgres:16-alpine
docker pull redis:7-alpine
docker pull nginx:1.27-alpine
docker pull adminer:4
docker pull nicolaka/netshoot:latest

# Verificar que el puerto 18010 está libre
ss -ltn | grep 18010 || echo "18010 libre"
```

Cada participante trabaja en su equipo, así que los nombres fijos no chocan. Si dos personas comparten host, asigna un sufijo de proyecto (`tienda-ana`, `tienda-luis`) y un rango de puertos (`18010 + 10*n`).
