# Redes especiales: host, none, macvlan y overlay

Comandos para la demo de la clase 2. Los de `macvlan` necesitan un host Linux conectado a la LAN del aula y una interfaz real. Ajusta `eth0`, la subred y la puerta de enlace antes de ejecutarlos.

## `none`: sin red

```bash
docker run --rm --network none alpine ip addr
docker run --rm --network none alpine ping -c1 1.1.1.1
```

Solo aparece `lo`. Es útil para procesos que no deben hablar con nadie.

## `host`: comparte la pila del host

```bash
docker run --rm --network host nginx:1.27-alpine
# en otra terminal
curl -s localhost:80 | head -3
```

No hay NAT ni mapeo de puertos: el contenedor escucha en el puerto del host. Dos contenedores con el mismo puerto no pueden convivir.

En Docker Desktop, `host` apunta a la VM Linux de Docker, no a macOS ni a Windows. El puerto no aparece en `localhost` del equipo anfitrión.

## Comparar `host` y bridge

```bash
# bridge: puerto publicado de forma explícita
docker run -d --name web-bridge -p 18020:80 nginx:1.27-alpine
curl -s localhost:18020 | head -1

# host: sin -p, el contenedor usa el 80 del host
docker run -d --name web-host --network host nginx:1.27-alpine
curl -s localhost:80 | head -1

docker rm -f web-bridge web-host
```

## `macvlan`: una IP de la LAN

```bash
# Ajusta la interfaz, la subred y la puerta de enlace a tu red real
ip -brief addr show eth0

docker network create -d macvlan \
  --subnet 192.168.1.0/24 \
  --gateway 192.168.1.1 \
  -o parent=eth0 lan

docker run -d --name web-lan --network lan --ip 192.168.1.240 nginx:1.27-alpine
curl -s http://192.168.1.240 | head -1
```

El contenedor aparece como un equipo más de la LAN. Limitaciones:

- Muchos switches inalámbricos no permiten varias MAC por puerto.
- El host no puede hablar con su propio contenedor `macvlan` salvo que crees otra interfaz `macvlan` en el host.
- La IP debe estar fuera del rango DHCP o reservada.
- Docker Desktop no expone la interfaz física de esta forma.

Limpieza:

```bash
docker rm -f web-lan
docker network rm lan
```

## `overlay`: varios hosts (concepto)

Una red `overlay` conecta contenedores que viven en máquinas distintas. En Swarm se crea con `docker network create -d overlay --attachable app`. En Kubernetes el equivalente son los Services y el CNI del clúster.

No se practica en este curso porque requiere varios nodos. La idea que hay que llevarse: el nombre del servicio resuelve a una IP virtual y el tráfico llega al contenedor esté donde esté.

## Preguntas para la puesta en común

1. ¿Qué aislamiento pierdes con `--network host`?
2. ¿Por qué `macvlan` no funciona igual en un portátil con wifi?
3. ¿Qué ventaja tiene una red user-defined frente a la `bridge` por defecto?
4. ¿Qué componente reparte el tráfico entre réplicas en Kubernetes?
