# Infraestructura del TPE

Esta carpeta contiene los artefactos propios del POC aprobado para desplegar The Store sobre un cluster K3s multi-nodo local.

El alcance contractual es:

- Vagrant aprovisiona VMs Ubuntu Server 24.04 LTS.
- Ansible configura sistema operativo, firewall, K3s e Ingress.
- La topologia inicial es 1 Control Plane y 2 Workers.
- La red privada es `192.168.56.0/24`.
- The Store se despliega sobre Kubernetes usando los manifiestos del repo.

## Estructura

```text
infra/
  Vagrantfile
  ansible/
    inventory/
      hosts.yml
    playbooks/
      site.yml
      deploy-store.yml
      add-worker.yml
    roles/
      common/
      k3s_server/
      k3s_agent/
      ingress/
      the_store_images/
```

La implementacion se completa de forma incremental siguiendo `docs/plan-ejecucion-k3s-the-store.md`.

## Topologia inicial

| VM | Rol | IP privada | CPU | RAM |
| --- | --- | --- | --- | --- |
| `k3s-control` | Control Plane | `192.168.56.10` | 2 | 2048 MB |
| `k3s-worker-1` | Worker | `192.168.56.11` | 2 | 2048 MB |
| `k3s-worker-2` | Worker | `192.168.56.12` | 2 | 2048 MB |

## Uso

Desde esta carpeta:

```bash
vagrant validate
vagrant up
vagrant status
```

La box usada es `bento/ubuntu-24.04`, compatible con VirtualBox y equivalente al requisito de Ubuntu Server 24.04 LTS del POC.

Si Vagrant queda esperando SSH o hay timeout de arranque, se puede abrir la consola grafica de VirtualBox con:

```powershell
$env:VAGRANT_GUI="true"
vagrant up k3s-control
```

Para verificar IPs:

```bash
vagrant ssh k3s-control -c 'hostname -I'
vagrant ssh k3s-worker-1 -c 'hostname -I'
vagrant ssh k3s-worker-2 -c 'hostname -I'
```
