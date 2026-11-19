# Acta de salida: `tienda-api` 4.0

| Dato | Valor |
|---|---|
| Pareja |  |
| Fecha |  |
| Decisión | Publicar / Publicar con excepción / No publicar |

La decisión se justifica con los cuatro hallazgos del informe del auditor. Copia este archivo a `acta.md` y rellénalo con tus salidas reales.

## Hallazgo 1. Imagen con privilegios

**Estado:** Abierto / Cerrado

Evidencia (pega la salida de `docker image inspect` y del uid en ejecución):

```text
```

Acción tomada en el Dockerfile:

```text
```

## Hallazgo 2. Contraseña sin rastro

**Estado:** Abierto / Cerrado

Evidencia (pega la salida de `docker history | grep -i password` y la línea de `compose.yaml` que monta el secreto):

```text
```

Acción tomada:

```text
```

## Hallazgo 3. Runtime abierto

**Estado:** Abierto / Cerrado

Evidencia (pega `CapEff`, el error al escribir en `/app`, el `tmpfs` y las dos redes):

```text
```

Acción tomada:

```text
```

¿Por qué Redis necesita `user: "999:1000"`?

```text
```

## Hallazgo 4. Pipeline sin control

**Estado:** Abierto / Cerrado

Evidencia (pega la salida de los gates en verde y de los dos casos en rojo):

```text
```

CVEs encontrados y capa a la que pertenecen (base Debian, dependencia Python o sin corrección):

```text
```

Acción tomada con el resultado del escaneo:

```text
```

¿Por qué el gate de usuario y tamaño no depende de la base de CVEs?

```text
```

¿Qué etiqueta se publicaría y por qué no `latest`?

```text
```

## Firma

Nombre del responsable de la pareja:

```text
```
