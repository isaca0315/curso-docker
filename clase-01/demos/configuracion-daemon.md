# Configuración de Docker (demo y laboratorio opcional)

## 1. Inspeccionar el entorno actual (seguro, sin cambios)

```bash
docker version
docker info --format 'Driver: {{.Driver}} | Cgroup: {{.CgroupVersion}} | Logs: {{.LoggingDriver}} | Root: {{.DockerRootDir}}'
docker context ls
docker system df
```

Preguntas:

- ¿Qué storage driver usa el host? ¿Por qué `overlay2` es el habitual?
- ¿Cuánto disco ocupan imágenes, contenedores, volúmenes y caché de build?
- ¿Qué contexto está activo?

## 2. Rotación de logs sin tocar el daemon

El driver `json-file` sin límite crece hasta llenar el disco. Se puede acotar por contenedor:

```bash
docker run -d --name logs-demo \
  --log-driver json-file \
  --log-opt max-size=1m \
  --log-opt max-file=2 \
  alpine:3.20 sh -c 'while true; do echo "linea de log"; sleep 0.01; done'

sleep 15

docker inspect -f '{{.HostConfig.LogConfig}}' logs-demo
docker inspect -f '{{.LogPath}}' logs-demo
sudo ls -lh "$(docker inspect -f '{{.LogPath}}' logs-demo)"
```

Deberías ver el archivo actual y una o dos rotaciones (`-json.log.1`, `.2`), ninguna mayor de 1 MB.

```bash
docker rm -f logs-demo
```

En producción conviene ponerlo como valor por defecto en `daemon.json`, no contenedor por contenedor.

## 3. `daemon.json` comentado

El archivo real no admite comentarios. Ejemplo completo en `demos/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-address-pools": [
    { "base": "172.30.0.0/16", "size": 24 }
  ],
  "no-new-privileges": true
}
```

| Clave | Efecto |
|---|---|
| `log-driver` / `log-opts` | Evita que los logs llenen el disco |
| `storage-driver` | Fija `overlay2`; no cambiarlo a ciegas en un host con imágenes |
| `live-restore` | Los contenedores siguen vivos al reiniciar el daemon |
| `default-address-pools` | Evita colisiones de subredes con la red corporativa/VPN |
| `no-new-privileges` | Los procesos no pueden ganar privilegios vía setuid |

Otras claves útiles: `"data-root"`, `"insecure-registries"`, `"registry-mirrors"`, `"max-concurrent-downloads"`, `"default-ulimits"`.

## 4. Aplicarlo (solo en una VM de práctica)

> No hacerlo en el equipo personal sin querer reiniciar Docker. Un JSON inválido impide arrancar el daemon.

```bash
# 1. Respaldo
sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak 2>/dev/null || true

# 2. Escribir la configuración
sudo install -m 644 daemon.json /etc/docker/daemon.json

# 3. Validar ANTES de reiniciar
sudo dockerd --validate --config-file /etc/docker/daemon.json

# 4. Aplicar
sudo systemctl restart docker

# 5. Verificar
docker info --format 'Logs: {{.LoggingDriver}} | LiveRestore: {{.LiveRestoreEnabled}}'
docker run --rm hello-world
```

Si algo falla:

```bash
sudo mv /etc/docker/daemon.json.bak /etc/docker/daemon.json
sudo systemctl restart docker
journalctl -u docker -n 50 --no-pager
```

`systemctl reload docker` solo recarga algunas opciones; los cambios de `daemon.json` requieren `restart` (salvo `live-restore` ya activo, que mantiene los contenedores).

## 5. Rootless (contenedor sin root en el host)

```bash
# Requiere el paquete docker-ce-rootless-extras
dockerd-rootless-setuptool.sh install
docker context use rootless
docker info --format '{{.SecurityOptions}}'
```

Ventaja: si el daemon se compromete, el atacante no es root del host. Limitaciones: no puede publicar puertos < 1024 sin configuración extra, algunas opciones de red y `--privileged` no funcionan igual.

## 6. Contextos remotos

```bash
docker context create servidor --docker "host=ssh://usuario@192.0.2.10"
docker context use servidor
docker ps
docker context use default
```

Útil para operar un host remoto sin copiar `/var/run/docker.sock` (copiar el socket es equivalente a dar root).

## 7. Errores típicos

| Error | Causa |
|---|---|
| Docker no arranca tras editar | JSON inválido o clave desconocida |
| Contenedores mueren al reiniciar el daemon | `live-restore` desactivado |
| Se pierden imágenes al cambiar `storage-driver` | El nuevo driver no ve las capas del anterior |
| Colisión de subredes con la VPN | Falta `default-address-pools` |
| Disco lleno | `json-file` sin `max-size` y/o caché de build |
| `permission denied` en el socket | Usuario sin grupo `docker` (equivale a root) |
