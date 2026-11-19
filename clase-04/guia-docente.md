# Guía del docente: clase 4

Guion de sesión para las 4 horas. Es un caso de estudio: el equipo va a publicar `tienda-api` 4.0 y un auditor entregó cuatro hallazgos el viernes. Cada bloque cierra uno. Los tiempos son relativos al inicio (00:00); el instructor comparte pantalla y los participantes trabajan en parejas en su propio equipo. No se usa Kubernetes en esta clase.

La guía del alumno es [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md) y se sigue en paralelo. Al final cada pareja entrega un acta de salida con la decisión de publicar o no publicar.

## Modalidad virtual

Cada participante construye la imagen y levanta el stack en su equipo. La imagen base y las dependencias conviene descargarlas antes de la sesión; el primer build en vivo depende de la conexión de cada uno. El escaneo con Trivy es opcional: si la base de datos no se descarga, se lee el informe guardado en `lab/informes/`.

**Material que conviene tener abierto:** [`slides.md`](slides.md), [`lab/guia-paso-a-paso.md`](lab/guia-paso-a-paso.md), [`lab/retos-auditoria.md`](lab/retos-auditoria.md), [`lab/informes/acta-ejemplo.md`](lab/informes/acta-ejemplo.md), [`evaluacion/rubrica-clase-04.md`](evaluacion/rubrica-clase-04.md) y una copia impresa de [`recursos/checklist-seguridad.md`](recursos/checklist-seguridad.md) por participante.

## Antes de la clase

### El día anterior

Pedir a cada participante que construya la imagen y pruebe el stack el día anterior:

```bash
cd clase-04/lab
cp secrets/db_password.txt.example secrets/db_password.txt
docker compose build api
docker compose up -d
curl -s localhost:18030/
docker compose down
```

La imagen `tienda-api:4.0` se construye en el paso 2 de la guía del alumno; el instructor la tiene lista para la demo. Si Trivy no está instalado, instalarlo antes o dejar el escaneo como lectura del informe guardado.

```bash
docker pull python:3.12-slim
docker pull postgres:16-alpine
docker pull redis:7-alpine
trivy image --download-db-only
```

### Al inicio de la sesión

Comprobar que el puerto 18030 está libre y que no queda un stack de otra clase:

```bash
docker compose -f clase-04/lab/compose.yaml ps
ss -ltn | grep 18030 || echo "18030 libre"
```

Si dos participantes comparten host, asigna un puerto (`18030 + n`) y un nombre de proyecto (`tienda-segura-ana`). En el material se usa el puerto único 18030.

## Agenda

| Hora | Bloque | Material | Checkpoint |
|---|---|---|---|
| 00:00-00:15 | Presentar el caso: informe del auditor y entregable | `slides.md` diapositiva 2 | Cada pareja sabe qué hallazgo cierra |
| 00:15-00:45 | Superficie de ataque: imagen, runtime, secretos y cadena de suministro | `slides.md` | Diferenciar imagen de runtime |
| 00:45-01:40 | Laboratorio A: hallazgos 1, 2 y 3 (pasos 0-3) | `lab/guia-paso-a-paso.md` | API responde, `/app` solo lectura, `CapEff=0`, secretos fuera de la imagen |
| 01:40-01:50 | Pausa | sin material | |
| 01:50-02:25 | Hallazgo 4: CVEs, SBOM, gates y etapas del pipeline | `slides.md` + `demos/02-escaneo-trivy.sh` | Saber por qué el gate no es la lista de CVEs |
| 02:25-03:10 | Laboratorio B: gates, escaneo, acta (pasos 4-6) | `lab/guia-paso-a-paso.md` | Gates en verde y en rojo, informe y SBOM abiertos |
| 03:10-03:45 | Auditoría cruzada en parejas | `lab/retos-auditoria.md` | Cada pareja explica un hallazgo y su control |
| 03:45-04:00 | Acta de salida, entregable y cierre del curso | `evaluacion/rubrica-clase-04.md` | Decisión de publicar escrita |

## Guion

### 00:00-00:15. Presentar el caso

Proyectar la diapositiva 2 y leer los cuatro hallazgos en voz alta. Repartir parejas. Cada pareja es el equipo de plataforma y debe decidir al final si publica la versión 4.0.

Pregunta disparadora: *¿cuál de los cuatro hallazgos se arregla con un Dockerfile y cuál solo se arregla en ejecución?* No responder todavía.

### 00:15-00:45. Superficie de ataque

Recorrer las diapositivas de modelo de amenazas. Marcar la frontera:

- Imagen: base, dependencias, código, usuario, etiquetas.
- Runtime: capacidades, sistema de archivos, red, límites, secretos.
- Cadena de suministro: build, gates, escaneo, firma, publicación.

Frase para repetir en la clase: *lo que se construye no se arregla al ejecutarlo, y lo que se ejecuta no se arregla reconstruyendo la imagen.* Ejemplo: añadir `USER` al Dockerfile no protege si Compose ejecuta `user: root`.

### 00:45-01:40. Laboratorio A, hallazgos 1, 2 y 3

Los participantes siguen los pasos 0 a 3. El instructor proyecta la guía y corre `demos/01-runtime-endurecido.sh` cuando el stack esté arriba.

**Checkpoint 1 (01:10).** `docker image inspect` muestra `10001:10001`, el uid en ejecución es 10001 y pip no está. Si alguien construyó la imagen de la clase 2 por error, comparar con `diff -u Dockerfile Dockerfile.hardened`.

**Checkpoint 2 (01:25).** `docker history tienda-api:4.0 | grep -i password` no devuelve nada y el archivo `secrets/db_password.txt` no aparece en `git status`. Aquí se cierra el hallazgo 2.

**Checkpoint 3 (01:40).** En la API: `/app/prueba` falla con `Read-only file system`, `/tmp/prueba` funciona y `CapEff` es cero. En la red, `backend` contiene db, redis y api; `edge` solo api.

**El punto del caso: Redis.** Si alguien quita `user: "999:1000"` para "endurecer más", Redis reinicia con `setpriv: setresuid failed`. `cap_drop: ALL` elimina `CAP_SETUID`, que el entrypoint necesita para bajar de root. La corrección es declarar el usuario, no devolver la capacidad. Postgres se deja sin `cap_drop` por el mismo motivo: `gosu` inicializa el volumen. Gastar 5 minutos aquí vale más que media diapositiva.

### 01:50-02:25. Hallazgo 4

Proyectar `demos/02-escaneo-trivy.sh` si Trivy está instalado; si no, abrir `lab/informes/README.md`. Explicar las tres capas del resultado: base Debian, paquetes Python y CVEs sin corrección.

La discusión central: el pipeline se bloquea con usuario root o tamaño, no con "hay un CVE". Un CVE nuevo en la base aparece sin que el equipo cambiara nada; si eso detiene la publicación, el equipo aprende a ignorar el rojo. El gate con umbral de `CRITICAL` corregible es una excepción controlada con fecha y responsable.

### 02:25-03:10. Laboratorio B

Los participantes ejecutan los gates en verde y en rojo (`python:3.12-slim`, `MAX_MB=50`), generan el SBOM y rellenan el acta con datos reales. Proyectar `demos/03-gates-ci.sh` como referencia.

Aviso antes de empezar: no copiar `ci/github-actions-ci.yml` a `.github/workflows/` en el repositorio del curso. Es un ejemplo para leer; el workflow no está activo.

### 03:10-03:45. Auditoría cruzada

Parejas distintas intercambian hallazgos. Cada pareja muestra una comprobación de `lab/retos-auditoria.md`, dice si es hallazgo real o ruido y nombra el control que lo cierra. Regla: no cambiar el `compose.yaml` de la clase; usar contenedores desechables.

Si el tiempo aprieta, hacer los retos 1 y 3 y dejar el 2 y el 4 para casa. Si sobra tiempo, `extra-60-min.md` tiene tres bloques de 20 minutos.

### 03:45-04:00. Acta y cierre

Cada pareja lee su decisión: publicar, publicar con excepción documentada o no publicar. No hay una única respuesta correcta si la justificación usa la evidencia del lab.

Cerrar con el hilo del curso: Docker construyó la app en la clase 1, Compose la conectó en la 2, Kubernetes la orquestó en la 3 y hoy se asegura y se automatiza. Recordar que el entregable vale 10 % del curso y que la demo oral es de 3 minutos.

## Planes B

| Situación | Plan |
|---|---|
| Un equipo no puede descargar la imagen base | Usar la imagen `tienda-api:4.0` que el instructor construyó y saltar el build en vivo |
| Trivy no instala o da 429 | Abrir `lab/informes/README.md`, explicar capas y marcar el escaneo como lectura |
| `docker compose up` falla por puerto ocupado | Cambiar el mapeo a `18030 + n` y el nombre del proyecto |
| El grupo va retrasado a las 02:25 | Hacer los gates en verde y en rojo, recortar la auditoría a los retos 1 y 3 |
| El grupo termina antes | `extra-60-min.md`: Trivy a fondo, runtime a mano, secretos de build con digest |
| Se rompe el stack de un participante | `docker compose down -v` y repetir desde el paso 0; los volúmenes solo guardan datos de prueba |

## Notas para el instructor

- El error de Redis con `cap_drop: ALL` es esperado y formativo. No lo corrijas antes de que aparezca.
- `sh` sigue existiendo en `python:3.12-slim`. Lo que se quita es el shell de login del usuario; para quitar el intérprete hace falta otra base. No prometas lo contrario.
- El SBOM cambia con la fecha de la imagen base. No memorices el número de CVEs; lee el informe del día.
- Si alguien pregunta por firmas o políticas de admisión: se explican, pero no se implementan porque requieren registry y clúster. El entregable se queda en Docker y Compose.
