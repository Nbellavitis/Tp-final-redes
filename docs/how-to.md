# How-to: K3s multi-nodo para The Store

Documento operativo para reproducir el POC.

## Estado

Fase 0 completada: estructura inicial del proyecto.

Fase 1 completada: imagenes Docker de The Store construidas localmente.

Fase 2 completada: `infra/Vagrantfile` define la topologia inicial de 3 VMs Ubuntu Server 24.04 LTS.

Nota: se usa la box `bento/ubuntu-24.04` para VirtualBox.

Fase 3 completada a nivel implementacion: Ansible base queda definido en el rol `common` y validado con `ansible-playbook --syntax-check`.

Nota: la ejecucion contra VMs debe correrla cada integrante desde su entorno, usando el inventario principal o el inventario alternativo para WSL segun corresponda.

Fase 4 completada a nivel implementacion: el rol `k3s_server` instala y configura K3s server en `k3s-control`.

Fase 5 completada a nivel implementacion: el rol `k3s_agent` une `k3s-worker-1` y `k3s-worker-2` al cluster usando automaticamente el token del Control Plane.

Fase 6 completada a nivel implementacion: el rol `k3s_kubeconfig` exporta `infra/kubeconfig` para operar el cluster desde el host.

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

1. Ingress Controller.
2. Distribucion de imagenes.
3. Deploy de The Store.
4. Alta de un nuevo Worker.

## Fase 3: Ansible base

El rol `common` prepara las VMs para Kubernetes:

- Instala paquetes base.
- Carga modulos de kernel `overlay` y `br_netfilter`.
- Configura `sysctl` para forwarding y bridge networking.
- Desactiva swap.
- Deja permitidos los puertos principales si UFW esta instalado.

Archivos implementados:

- `infra/ansible/playbooks/site.yml`
- `infra/ansible/roles/common/defaults/main.yml`
- `infra/ansible/roles/common/handlers/main.yml`
- `infra/ansible/roles/common/tasks/main.yml`
- `infra/ansible/inventory/hosts.yml`
- `infra/ansible/inventory/hosts-wsl.yml`
- `infra/ansible/scripts/prepare-wsl-keys.sh`

Validaciones realizadas:

```bash
ruby -c infra/Vagrantfile
bash -n infra/ansible/scripts/prepare-wsl-keys.sh
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check
ansible-playbook -i inventory/hosts-wsl.yml playbooks/site.yml --syntax-check
```

Comando:

```bash
cd infra/ansible
ansible -i inventory/hosts.yml k3s_cluster -m ping
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags common
```

Si Ansible corre desde WSL y no llega a `192.168.56.0/24`, usar el inventario NAT opcional:

Desde PowerShell:

```powershell
cd "C:\Users\nico\Desktop\ITBA\Redes\Tp-final\infra"
$env:VAGRANT_EXPOSE_SSH="true"
vagrant reload
```

Desde WSL:

```bash
cd infra/ansible
bash scripts/prepare-wsl-keys.sh
export NAT_SSH_HOST="$(awk '/nameserver/ {print $2; exit}' /etc/resolv.conf)"
ansible -i inventory/hosts-wsl.yml k3s_cluster -m ping
ansible-playbook -i inventory/hosts-wsl.yml playbooks/site.yml --tags common
```

## Fase 4: K3s Control Plane

El rol `k3s_server` instala K3s server en `k3s-control` y configura:

- IP del nodo y advertise address: `192.168.56.10`.
- Pod CIDR: `10.42.0.0/16`.
- Service CIDR: `10.43.0.0/16`.
- Flannel backend: `vxlan`.
- Kubeconfig legible en `/etc/rancher/k3s/k3s.yaml`.
- Traefik deshabilitado para instalar luego un Ingress Controller `nginx` compatible con `dist/kubernetes.yaml`.
- Token de join disponible como fact de Ansible para la fase de Workers.

Archivos implementados:

- `infra/ansible/roles/k3s_server/defaults/main.yml`
- `infra/ansible/roles/k3s_server/handlers/main.yml`
- `infra/ansible/roles/k3s_server/tasks/main.yml`

Comando con inventario principal:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags common,k3s_server
```

Comando con inventario alternativo para WSL:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts-wsl.yml playbooks/site.yml --tags common,k3s_server
```

Validacion esperada:

```bash
ansible -i inventory/hosts.yml control_plane -b -m command -a "/usr/local/bin/kubectl get nodes -o wide"
```

Resultado esperado:

```text
k3s-control   Ready
```

## Fase 5: K3s Workers

El rol `k3s_agent` une los Workers al cluster K3s:

- Lee el token generado por el Control Plane desde los facts de Ansible.
- Configura cada worker con `server: https://192.168.56.10:6443`.
- Usa la IP privada real del nodo como `node-ip`.
- Instala `k3s-agent` de forma idempotente.
- Espera a que cada worker aparezca como nodo de Kubernetes.

Archivos implementados:

- `infra/ansible/roles/k3s_agent/defaults/main.yml`
- `infra/ansible/roles/k3s_agent/handlers/main.yml`
- `infra/ansible/roles/k3s_agent/tasks/main.yml`
- `infra/ansible/inventory/hosts.yml`
- `infra/ansible/inventory/hosts-wsl.yml`

Comando con inventario principal:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags common,k3s_server,k3s_agent
```

Comando con inventario alternativo para WSL:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts-wsl.yml playbooks/site.yml --tags common,k3s_server,k3s_agent
```

Validacion esperada:

```bash
ansible -i inventory/hosts.yml control_plane -b -m command -a "/usr/local/bin/kubectl get nodes -o wide"
```

Resultado esperado:

```text
k3s-control    Ready
k3s-worker-1   Ready
k3s-worker-2   Ready
```

## Fase 6: Kubeconfig local

El rol `k3s_kubeconfig` exporta el kubeconfig del Control Plane a `infra/kubeconfig`:

- Lee `/etc/rancher/k3s/k3s.yaml`.
- Reemplaza `https://127.0.0.1:6443` por `https://192.168.56.10:6443`.
- Escribe el archivo local con permisos `0600`.
- El archivo queda ignorado por Git porque es un artefacto local.

Archivos implementados:

- `infra/ansible/roles/k3s_kubeconfig/defaults/main.yml`
- `infra/ansible/roles/k3s_kubeconfig/tasks/main.yml`
- `infra/ansible/playbooks/site.yml`

Comando con inventario principal:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags kubeconfig
```

Comando con inventario alternativo para WSL:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts-wsl.yml playbooks/site.yml --tags kubeconfig
```

Uso desde la raiz del repo:

```bash
export KUBECONFIG="$PWD/infra/kubeconfig"
kubectl get nodes -o wide
```

Resultado esperado:

```text
k3s-control    Ready
k3s-worker-1   Ready
k3s-worker-2   Ready
```

## Referencia principal

El plan detallado esta en `docs/plan-ejecucion-k3s-the-store.md`.
