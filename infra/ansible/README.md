# Ansible

Automatizacion del cluster K3s local.

## Inventario

El inventario vive en `inventory/hosts.yml` y separa:

- `control_plane`
- `workers`
- `k3s_cluster`

## Playbooks

- `playbooks/site.yml`: flujo principal de configuracion del cluster.
- `playbooks/deploy-store.yml`: despliegue de The Store.
- `playbooks/add-worker.yml`: alta controlada de un nuevo worker.

Para ejecutar solo la preparacion base de sistema operativo cuando Ansible puede llegar a `192.168.56.0/24`:

```bash
cd infra/ansible
ansible-playbook playbooks/site.yml --tags common
```

## Roles

- `common`: prerequisitos del sistema operativo.
- `k3s_server`: instalacion del Control Plane.
- `k3s_agent`: union de Workers.
- `k3s_cluster_validation`: validacion de nodos `Ready` desde el Control Plane.
- `k3s_kubeconfig`: exportacion de kubeconfig para operar desde el host.
- `ingress`: instalacion y validacion de `ingress-nginx`.
- `the_store_images`: distribucion/importacion de imagenes locales en containerd de K3s.

K3s se instala con version pinneada `v1.35.5+k3s1` en server y agents para evitar que una re-ejecucion o un worker agregado mas adelante tome una version distinta del canal `stable`.

`ingress-nginx` se instala con version pinneada `controller-v1.13.1`, manifiesto `provider/baremetal` y controller con `hostNetwork` en `k3s-control` para exponer HTTP/HTTPS por `192.168.56.10`.

## Fases implementadas

### Fase 3: base del sistema operativo

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags common
```

### Fase 4: K3s Control Plane

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags common,k3s_server
```

Validacion:

```bash
ansible -i inventory/hosts.yml control_plane -b -m command -a "/usr/local/bin/kubectl get nodes -o wide"
ansible -i inventory/hosts.yml control_plane -b -m command -a "/usr/local/bin/kubectl wait --for=condition=Ready node/k3s-control --timeout=180s"
```

### Fase 5: K3s Workers

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags common,k3s_server,k3s_agent
```

Validacion:

```bash
ansible -i inventory/hosts.yml control_plane -b -m command -a "/usr/local/bin/kubectl get nodes -o wide"
ansible -i inventory/hosts.yml control_plane -b -m command -a "/usr/local/bin/kubectl wait --for=condition=Ready nodes --all --timeout=180s"
```

### Fase 6: kubeconfig local

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags kubeconfig
```

Uso:

```bash
cd ../..
export KUBECONFIG="$PWD/infra/kubeconfig"
kubectl get nodes -o wide
```

### Fase 7: Ingress Controller

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags ingress
```

Validacion:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass nginx
```

### Fase 8: imagenes de The Store

Desde la raiz del repo:

```bash
bash scripts/export-images.sh
```

Desde `infra/ansible`:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml --tags images
```

Validacion:

```bash
ansible -i inventory/hosts.yml k3s_cluster -b -m command -a "/usr/local/bin/k3s ctr images list"
```

## Ejecucion por plataforma

### macOS, Linux o Windows con acceso directo a host-only

Usar el inventario principal:

```bash
cd infra/ansible
ansible -i inventory/hosts.yml k3s_cluster -m ping
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags common
```

### Windows + WSL sin ruta a host-only

Vagrant y VirtualBox se ejecutan desde Windows. Ansible corre desde WSL. Si WSL no llega a `192.168.56.0/24`, usar `inventory/hosts-wsl.yml`, que usa puertos NAT expuestos por Vagrant.

Desde PowerShell, activar puertos NAT:

```powershell
cd "C:\Users\nico\Desktop\ITBA\Redes\Tp-final\infra"
$env:VAGRANT_EXPOSE_SSH="true"
vagrant reload
```

Desde WSL, preparar claves con permisos correctos:

```bash
cd /mnt/c/Users/nico/Desktop/ITBA/Redes/Tp-final/infra/ansible
bash scripts/prepare-wsl-keys.sh
```

Obtener la IP del host Windows vista desde WSL:

```bash
export NAT_SSH_HOST="$(awk '/nameserver/ {print $2; exit}' /etc/resolv.conf)"
```

Validar conectividad y ejecutar fase 3:

```bash
ansible -i inventory/hosts-wsl.yml k3s_cluster -m ping
ansible-playbook -i inventory/hosts-wsl.yml playbooks/site.yml --tags common
```

El inventario WSL solo resuelve SSH/Ansible por NAT. El kubeconfig generado apunta a `https://192.168.56.10:6443`; si WSL no tiene ruta a la red host-only, usar `kubectl` desde Windows/macOS/Linux con acceso a esa red o validar desde el Control Plane con `vagrant ssh k3s-control -c 'sudo kubectl ...'`.
