# Guía del docente: clase 4

Guion de sesión para las 4 horas. Los tiempos son relativos al inicio (00:00). La guía del alumno es [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md) y se sigue en paralelo. Es la última clase, así que el cierre repasa el curso completo además de la sesión. El instructor comparte pantalla.

## Modalidad virtual

Cada participante construye la imagen y levanta el stack en su equipo. La imagen base, las dependencias y, si se usa, la base de Trivy se descargan antes de la sesión; un build completo durante la clase depende de la conexión de cada uno.

**Material que conviene tener abierto:** [`slides.md`](slides.md), [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md), [`lab/retos-auditoria.md`](lab/retos-auditoria.md), [`evaluacion/rubrica-clase-04.md`](evaluacion/rubrica-clase-04.md) y una copia impresa de [`recursos/checklist-seguridad.md`](recursos/checklist-seguridad.md) por participante.

## Antes de la clase

### El día anterior

Pedir a cada participante que construya la imagen y pruebe el stack el día anterior:

```bash
cd clase-04/lab
cp secrets/db_password.txt.example secrets/db_password.txt
docker compose build api
docker compose up -d --wait
docker compose ps
./ci/verificar-imagen.sh tienda-api:4.0
curl -s localhost:18030/
```

Descargar las imágenes y, si se va a escanear en la sesión, la base de Trivy:

```bash
docker pull python:3.12-slim
docker pull postgres:16-alpine
docker pull redis:7-alpine
trivy image --download-db-only
```

Guardar una salida de Trivy y un SBOM en `lab/informes/` por si falla la conexión de algún participante. El laboratorio puede seguir sin Trivy: el escaneo se explica como informe y los gates deterministas no dependen de la base de CVEs.

### Quince minutos antes

- Comprobar que 18030 está libre: `ss -ltn | grep 18030`.
- Verificar que `secrets/db_password.txt` existe y no está en Git.
- Ejecutar una vez [`demos/01-runtime-endurecido.sh`](demos/01-runtime-endurecido.sh) y [`demos/03-gates-ci.sh`](demos/03-gates-ci.sh).
- Probar el reto 3: `docker compose exec -T api sh -c 'touch /app/x'` debe fallar.
- Si la clase 4 es al día siguiente de la 3, comprobar que el clúster `curso` sigue vivo y que la imagen `tienda-api:4.0` está cargada en el nodo con `kind load docker-image tienda-api:4.0 --name curso`. Si no hay clúster, el paso 6 del laboratorio es opcional.

## Agenda

| Hora | Bloque | Material |
|---|---|---|
| 00:00-00:15 | Repaso de la clase 3 y verificación del stack | `docker compose ps` |
| 00:15-00:55 | Modelo de amenazas: imagen, runtime, secretos, supply chain y privilegios | `slides.md` |
| 00:55-01:50 | Lab 4a, pasos 0 a 3 | `lab/guia-paso-a-paso.md` |
| 01:50-02:00 | Pausa | |
| 02:00-02:40 | CVEs, SBOM, firmas, gates y etapas del pipeline | `slides.md` + `demos/02-escaneo-trivy.sh` |
| 02:40-03:25 | Lab 4b, pasos 4 a 7 | `lab/guia-paso-a-paso.md` |
| 03:25-03:55 | Retos de auditoría en parejas | `lab/retos-auditoria.md` |
| 03:55-04:00 | Entregable, cierre del curso y siguientes pasos | `evaluacion/rubrica-clase-04.md` |

La agenda suma 240 min. Los cuatro retos son parte del plan; si el grupo termina antes, se amplía la puesta en común y se recorre el workflow de GitHub Actions. Si sobra más tiempo, [`extra-60-min.md`](extra-60-min.md) tiene tres bloques de 20 min.

## 00:00-00:15. Repaso y entornos

1. Pedir una frase por persona sobre la clase 3: qué crea un pod, qué hace un Service, diferencia entre readiness y liveness.
2. Comprobar el stack de la clase 4:

```bash
cd clase-04/lab
docker compose ps
docker image inspect tienda-api:4.0 --format '{{.Config.User}}'
```

3. Presentar el hilo: la imagen de la clase 3 ya funciona en Kubernetes, pero cualquiera que la descargue puede leer su historial, ejecutarla como root o aprovechar una capacidad de más. Hoy se reduce esa superficie y se automatiza la comprobación.
4. Si alguien no tiene la imagen, construirla ahora. El build tarda menos si `python:3.12-slim` ya está descargada.

## 00:15-00:55. Modelo de amenazas

Recorrer las diapositivas con preguntas:

- Qué lleva la imagen y qué se puede leer en ella.
- Qué usuario ejecuta el proceso y qué puede escribir.
- Qué capacidades conserva y qué permite cada una.
- Dónde viven los secretos y por qué `ENV` no es un sitio seguro.
- Qué riesgo tiene montar el socket de Docker dentro de un contenedor.
- Qué diferencia hay entre rootless, usuario no root y `cap_drop`.
- Qué aporta un escaneo y qué no.

Preguntas: ¿qué control impide escribir un binario en `/app`?, ¿qué control impide que un setuid eleve privilegios?, ¿por qué una imagen pequeña no es automáticamente segura?

Checkpoint: los 6 distinguen un control de imagen de un control de runtime.

## 00:55-01:50. Laboratorio 4a, pasos 0 a 3

Todos trabajan desde `clase-04/lab`. Circular con esta tabla.

| Hora | Deberían estar en | Señal de que va bien |
|---|---|---|
| 01:05 | Paso 1 | Identifican usuario sin shell, sin pip y etiquetas OCI |
| 01:15 | Paso 2 | `uid 10001`, tamaño cercano a 192 MiB, `pip no está` |
| 01:35 | Paso 3 | Tres servicios `healthy` y la API responde en 18030 |
| 01:45 | Paso 3, comprobaciones | `/app` rechaza escritura, `/tmp` la acepta, `CapEff` en cero |
| 01:50 | Paso 3 cerrado | Saben qué control aplica la imagen y cuál el runtime |

Puntos donde se traba la gente:

- Redis reinicia con `setpriv: setresuid failed` si se quita `user: "999:1000"`. Es el mejor ejemplo de que `cap_drop: ALL` tiene coste.
- `Read-only file system`: falta `tmpfs: /tmp` o el proceso escribe en `/app`.
- El puerto 18030 no aparece si la API solo está en `backend`. Debe estar también en `edge`.
- `docker compose exec` falla si el contenedor está reiniciando. Mirar `ps` antes.
- El tamaño no baja mucho respecto a la clase 2: el objetivo es la superficie, no el disco.

Si a las 01:35 alguien sigue en el paso 2, emparejarlo y continuar desde el paso 3 con la imagen ya construida.

## 01:50-02:00. Pausa

Comprobar que los 6 tienen los tres servicios sanos y que pueden ejecutar comandos dentro de la API. Resolver ahora los puertos y los volúmenes.

## 02:00-02:40. CVEs, SBOM y pipeline

Explicar sin convertir la clase en una lista de CVEs:

- Un CVE en la base no siempre es explotable; el contexto decide.
- El SBOM responde qué lleva la imagen y permite reaccionar después.
- Los gates deterministas (usuario, tamaño, configuración) no dependen del mundo.
- El escaneo como gate necesita umbral, fecha y excepciones; si no, el pipeline se rompe solo.
- Un tag mutable no identifica lo desplegado; el digest sí.
- El pipeline tiene etapas: build, test, gates, escaneo, firma, publicación y despliegue.

Demo de escaneo, si Trivy está disponible:

```bash
cd clase-04/demos
./02-escaneo-trivy.sh
```

Qué señalar: CVEs de la base y de Python, el SBOM CycloneDX y la diferencia entre un fallo corregible y uno que depende del proveedor.

Si no hay Trivy o red, abrir el informe guardado en `lab/informes/` y explicar las mismas columnas. No gastar el bloque esperando una descarga.

## 02:40-03:25. Laboratorio 4b, pasos 4 a 7

| Hora | Deberían estar en | Señal de que va bien |
|---|---|---|
| 02:55 | Paso 4 | Los gates pasan y saben qué comprueba cada uno |
| 03:10 | Paso 5 | Informe de Trivy y SBOM, o explicación del informe guardado |
| 03:20 | Paso 6 | El overlay aplica `securityContext` en Kubernetes, si hay clúster |
| 03:25 | Paso 7 | Saben qué etapa bloquea la publicación y qué permiso necesita el SARIF |

Errores de este bloque:

- El gate no puede leer el uid porque la imagen no tiene Python. Ajustar el comando o usar `docker image inspect`.
- El gate de tamaño falla: revisar qué se copió al runtime, no subir el umbral sin explicar.
- El SARIF no aparece: falta `security-events: write`.
- El overlay no encuentra la base: ejecutar desde `lab/` con `-k k8s`.
- `ImagePullBackOff` en el clúster: `kind load docker-image tienda-api:4.0 --name curso`.

Si el grupo va justo, saltar el paso 6 (Kubernetes) y hacer el 7 leyendo el workflow. El endurecimiento de runtime ya se vio en Compose.

## 03:25-03:55. Retos de auditoría

Presentar [`lab/retos-auditoria.md`](lab/retos-auditoria.md) y trabajar en parejas.

| Min | Reto | Qué se aprende |
|---|---|---|
| 03:25-03:32 | 1. Secreto en la imagen | `ENV` y el historial filtran la contraseña |
| 03:32-03:39 | 2. Capacidad de más | `NET_ADMIN` y el valor de `cap_drop: ALL` |
| 03:39-03:47 | 3. Solo lectura y `tmpfs` | Qué rompe y qué directorio hay que abrir |
| 03:47-03:55 | 4. Etiqueta móvil | Tag contra digest y reproducibilidad |

Reglas para el instructor:

- El plan incluye los cuatro retos. Si surge una emergencia de tiempo, el recorte mínimo son los retos 1 y 3; el 2 y el 4 quedan como deberes.
- No permitir cambios en el `compose.yaml` de la clase. Los retos usan contenedores desechables.
- En el reto 2, comparar `CapEff` con el de la API. Si la API no da cero, revisar `cap_drop`.
- En el reto 4, usar el digest que devuelva el comando en ese momento; el ejemplo del documento puede haber cambiado.
- Al terminar, borrar `/tmp/auditoria` y la imagen `auditoria:env`.

Checkpoint: cada pareja cuenta un hallazgo y el control que lo evita.

## 03:55-04:00. Entregable y cierre del curso

1. Recordar el entregable: stack endurecido, salida de los gates, informe de Trivy y SBOM, y dos frases sobre el gate de tamaño y el Dockerfile endurecido.
2. Mostrar la rúbrica y el checklist.
3. Cerrar el curso con tres preguntas al grupo, no una por persona:
   - ¿Qué control de los que aplicamos cambiaría más el impacto de un proceso comprometido?
   - ¿Qué no automatizaríamos como gate y por qué?
   - ¿Qué haría falta para llevar este stack a producción?
4. Recordar los siguientes pasos: registro de imágenes, firma con `cosign`, políticas con `OPA` o `Kyverno`, escaneo continuo y gestión de secretos.
5. Limpieza, si no se reutiliza el entorno:

```bash
cd clase-04/lab
docker compose down -v
docker rmi tienda-api:4.0 auditoria:env 2>/dev/null || true
kind delete cluster --name curso 2>/dev/null || true
```

No borrar `clase-02/lab/app/Dockerfile.hardened`: es la referencia de la imagen endurecida y la usan las dos clases.

## Si algo falla en vivo

| Síntoma | Qué hacer |
|---|---|
| Redis reinicia con `setresuid failed` | `cap_drop: ALL` quita `SETUID`; declarar `user: "999:1000"` |
| El puerto 18030 no aparece | La API solo está en `backend`; añadir `edge` |
| `Read-only file system` | Falta `tmpfs: /tmp` o el proceso escribe en `/app` |
| El gate no puede leer el uid | La imagen no tiene Python; ajustar el comando |
| Trivy tarda o falla por red | Usar el informe guardado; el escaneo no es un gate obligatorio |
| El SARIF no aparece | Falta `security-events: write` en el workflow |
| `ImagePullBackOff` | `kind load docker-image tienda-api:4.0 --name curso` |
| El overlay no encuentra la base | Ejecutar desde `lab/` con `-k k8s` |
| La contraseña aparece en `docker history` | Se pasó como `ARG` o `ENV`; montarla en ejecución |
| El grupo va atrasado | Saltar el paso 6 y hacer los retos 1 y 3; el resto queda para casa |

## Después de la clase

- Revisar que los entregables incluyan la salida real de los gates y un informe, además de las capturas.
- Cerrar el curso con una nota de qué quedó pendiente por participante.
- Guardar los informes de Trivy y los SBOM como ejemplo para la siguiente edición.
- Si cambiaste algo del material, actualizar `slides.md` y las capturas de resultados medidos.
