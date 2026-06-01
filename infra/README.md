# Infraestructura del TPE

Esta carpeta contiene los artefactos propios del POC aprobado para desplegar The Store sobre un cluster K3s multi-nodo local.

El alcance contractual es:

- Vagrant aprovisiona VMs Ubuntu Server 24.04 LTS.
- Ansible configura sistema operativo, firewall, K3s e Ingress.
- La topologia inicial es 1 Control Plane y 2 Workers.
- La fase 11 agrega `k3s-worker-3` como Worker adicional por Vagrant + Ansible.
- La red privada es `192.168.56.0/24`.
- K3s queda pinneado a `v1.35.5+k3s1` para que el cluster sea reproducible.
- Flannel VXLAN usa la interfaz host-only `eth1` para transportar Pods sobre `192.168.56.0/24`.
- El Ingress Controller es `ingress-nginx` pinneado a `controller-v1.13.1` y expuesto en `192.168.56.10:80/443`.
- The Store se despliega sobre Kubernetes usando los manifiestos del repo.
- La validacion funcional de fase 10 se ejecuta con `scripts/validate-store.sh` contra el Ingress `192.168.56.10` usando `Host: localhost`.

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
      k3s_cluster_validation/
      k3s_kubeconfig/
      ingress/
      the_store_images/
      the_store_deploy/
```

La implementacion se completa de forma incremental siguiendo `docs/plan-ejecucion-k3s-the-store.md`.

## Topologia inicial

| VM | Rol | IP privada | CPU | RAM |
| --- | --- | --- | --- | --- |
| `k3s-control` | Control Plane | `192.168.56.10` | 2 | 2048 MB |
| `k3s-worker-1` | Worker | `192.168.56.11` | 2 | 2048 MB |
| `k3s-worker-2` | Worker | `192.168.56.12` | 2 | 2048 MB |
| `k3s-worker-3` | Worker agregado en fase 11 | `192.168.56.13` | 2 | 2048 MB |

`k3s-worker-3` esta definido con `autostart: false`: un `vagrant up` inicial levanta solo la topologia aprobada de 1 Control Plane y 2 Workers. Para la fase 11 se crea explicitamente con `vagrant up k3s-worker-3`.

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
vagrant ssh k3s-worker-3 -c 'hostname -I'
```

## Uso con Ansible desde WSL

El flujo principal usa la red privada `192.168.56.0/24`, que suele funcionar directo en macOS, Linux y Windows.

En WSL puede ocurrir que no exista ruta directa a la red host-only de VirtualBox. Para ese caso, el `Vagrantfile` puede exponer SSH por puertos NAT si se activa `VAGRANT_EXPOSE_SSH=true`:

| VM | Puerto host |
| --- | --- |
| `k3s-control` | `2222` |
| `k3s-worker-1` | `2200` |
| `k3s-worker-2` | `2201` |
| `k3s-worker-3` | `2202` |

Desde PowerShell:

```powershell
cd "C:\Users\nico\Desktop\ITBA\Redes\Tp-final\infra"
$env:VAGRANT_EXPOSE_SSH="true"
vagrant reload
```

Este modo alternativo expone SSH para Ansible, no el API Server de Kubernetes. Si WSL no tiene ruta a `192.168.56.0/24`, el kubeconfig exportado no funcionara desde WSL; validar con `vagrant ssh k3s-control -c 'sudo kubectl ...'` o usar `kubectl` desde un host con acceso a la red host-only.
