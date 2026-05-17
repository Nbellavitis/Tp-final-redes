# How-to: K3s multi-nodo para The Store

Documento operativo para reproducir el POC.

## Estado

Fase 0 completada: estructura inicial del proyecto.

Fase 1 completada: imagenes Docker de The Store construidas localmente.

Fase 2 completada: `infra/Vagrantfile` define la topologia inicial de 3 VMs Ubuntu Server 24.04 LTS.

Nota: se usa la box `bento/ubuntu-24.04` para VirtualBox.

| Imagen | ID | Tamano aproximado |
| --- | --- | --- |
| `the-store-catalog:latest` | `22ad6f00cbad` | 292 MB |
| `the-store-cart:latest` | `92dc0e42eb01` | 788 MB |
| `the-store-checkout:latest` | `ce362f04d97b` | 984 MB |
| `the-store-orders:latest` | `25e8cdb0556f` | 1.08 GB |
| `the-store-ui:latest` | `1d6caec3d867` | 1.07 GB |

Comando usado:

```bash
bash scripts/build-images.sh
```

Topologia Vagrant inicial:

| VM | Rol | IP privada | CPU | RAM |
| --- | --- | --- | --- | --- |
| `k3s-control` | Control Plane | `192.168.56.10` | 2 | 2048 MB |
| `k3s-worker-1` | Worker | `192.168.56.11` | 2 | 2048 MB |
| `k3s-worker-2` | Worker | `192.168.56.12` | 2 | 2048 MB |

Comandos de fase 2:

```bash
cd infra
vagrant validate
vagrant up
vagrant status
```

Las fases siguientes completaran:

1. Ansible base e idempotente.
2. Instalacion de K3s server y agents.
3. Ingress Controller.
4. Distribucion de imagenes.
5. Deploy de The Store.
6. Alta de un nuevo Worker.

## Referencia principal

El plan detallado esta en `docs/plan-ejecucion-k3s-the-store.md`.
