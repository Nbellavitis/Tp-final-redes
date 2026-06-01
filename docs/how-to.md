# How-to: K3s multi-nodo para The Store

Documento operativo para reproducir el POC.

## Estado

Fase 0 completada: estructura inicial del proyecto.

Fase 1 completada: imagenes Docker de The Store construidas localmente.

Fase 2 completada: `infra/Vagrantfile` define la topologia inicial de 3 VMs Ubuntu Server 24.04 LTS.

Nota: se usa la box `bento/ubuntu-24.04` para VirtualBox.

Fase 3 completada a nivel implementacion: Ansible base queda definido en el rol `common` y validado con `ansible-playbook --syntax-check`.

Nota: la ejecucion contra VMs debe correrla cada integrante desde su entorno, usando el inventario principal o el inventario alternativo para WSL segun corresponda.

Fase 4 completada a nivel implementacion: el rol `k3s_server` instala y configura K3s server en `k3s-control`, usando una version pinneada y validando que el nodo quede `Ready`.

Fase 5 completada a nivel implementacion: el rol `k3s_agent` une `k3s-worker-1` y `k3s-worker-2` al cluster usando automaticamente el token del Control Plane y validando que ambos workers queden `Ready`.

Fase 6 completada a nivel implementacion: el rol `k3s_kubeconfig` exporta `infra/kubeconfig` para operar el cluster desde el host.

Fase 7 completada a nivel implementacion: el rol `ingress` instala `ingress-nginx` compatible con la clase `nginx` del manifiesto de The Store y valida que el controller quede listo.

Fase 8 implementada y validada: el rol `the_store_images` copia e importa el archivo de imagenes exportado en todos los nodos K3s.

Fase 9 implementada y validada: el rol `the_store_deploy` aplica The Store en namespace `the-store`, espera deployments/pods listos y valida acceso HTTP por Ingress.

Tags de imagen esperados:

- `the-store-catalog:latest`
- `the-store-cart:latest`
- `the-store-checkout:latest`
- `the-store-orders:latest`
- `the-store-ui:latest`

Comando usado:

```bash
bash scripts/build-images.sh
```

Nota: los Dockerfiles Java ejecutan `chmod +x ./mvnw` durante el build para que el wrapper funcione aunque el checkout local no preserve el bit ejecutable.

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

1. Validacion funcional de The Store.
2. Alta de un nuevo Worker.

## Fase 3: Ansible base

El rol `common` prepara las VMs para Kubernetes:

- Instala paquetes base.
- Carga modulos de kernel `overlay` y `br_netfilter`.
- Configura `sysctl` para forwarding y bridge networking.
- Desactiva swap.
- Deja permitidos los puertos principales si UFW esta instalado.
- Mantiene el alcance acotado a Kubernetes/K3s y diagnostico, sin componentes de storage fuera del POC.

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

Nota: el inventario WSL expone SSH por NAT para Ansible. Si WSL no tiene ruta a `192.168.56.0/24`, el kubeconfig exportado no servira desde WSL; en ese caso validar con `vagrant ssh k3s-control -c 'sudo kubectl ...'` o ejecutar `kubectl` desde un host con acceso a la red host-only.

## Fase 4: K3s Control Plane

El rol `k3s_server` instala K3s server en `k3s-control` y configura:

- Version K3s pinneada: `v1.35.5+k3s1`.
- IP del nodo y advertise address: `192.168.56.10`.
- Pod CIDR: `10.42.0.0/16`.
- Service CIDR: `10.43.0.0/16`.
- Flannel backend: `vxlan`.
- Flannel iface: `eth1`, para que VXLAN use la red host-only `192.168.56.0/24` y no la NAT duplicada de VirtualBox.
- Kubeconfig legible en `/etc/rancher/k3s/k3s.yaml`.
- Traefik deshabilitado para instalar luego un Ingress Controller `nginx` compatible con `dist/kubernetes.yaml`.
- Token de join disponible como fact de Ansible para la fase de Workers.
- Validacion explicita de que `k3s-control` quede con condicion `Ready`.

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

- Usa la misma version K3s pinneada que el Control Plane: `v1.35.5+k3s1`.
- Lee el token generado por el Control Plane desde los facts de Ansible.
- Configura cada worker con `server: https://192.168.56.10:6443`.
- Usa la IP privada real del nodo como `node-ip`.
- Instala el agent de forma idempotente, detectando el binario `/usr/local/bin/k3s`.
- Espera a que cada worker quede con condicion `Ready`.

Archivos implementados:

- `infra/ansible/roles/k3s_agent/defaults/main.yml`
- `infra/ansible/roles/k3s_agent/handlers/main.yml`
- `infra/ansible/roles/k3s_agent/tasks/main.yml`
- `infra/ansible/roles/k3s_cluster_validation/defaults/main.yml`
- `infra/ansible/roles/k3s_cluster_validation/tasks/main.yml`
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

Importante para WSL: este rol siempre renderiza el kubeconfig contra `https://192.168.56.10:6443`. Si WSL no tiene ruta a esa red privada, el archivo sirve como artefacto generado pero `kubectl` debe ejecutarse desde el host con acceso host-only o desde el Control Plane por SSH.

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

## Fase 7: Ingress Controller

El rol `ingress` instala `ingress-nginx` para exponer servicios HTTP/HTTPS en K3s:

- Usa `ingress-nginx` version `controller-v1.13.1`.
- Aplica el manifiesto oficial `provider/baremetal`.
- Ejecuta el controller con `hostNetwork` en `k3s-control` para publicar explicitamente `192.168.56.10:80` y `192.168.56.10:443`.
- Valida que el deployment del controller quede `Available`.
- Valida pods del controller `Ready`.
- Valida que exista la `IngressClass` `nginx`.
- Valida que el Service `ingress-nginx-controller` sea `NodePort`.
- Valida que los puertos `80` y `443` respondan en la IP privada del Control Plane.

Archivos implementados:

- `infra/ansible/roles/ingress/defaults/main.yml`
- `infra/ansible/roles/ingress/tasks/main.yml`
- `infra/ansible/playbooks/site.yml`

Comando con inventario principal:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags ingress
```

Validacion esperada desde la raiz del repo:

```bash
export KUBECONFIG="$PWD/infra/kubeconfig"
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass nginx
```

Resultado esperado:

```text
ingress-nginx-controller   Ready/Running
ingress-nginx-controller   NodePort
nginx                      IngressClass
```

## Fase 8: Distribucion de imagenes

El rol `the_store_images` distribuye las imagenes locales de The Store a containerd de K3s:

- Usa por defecto el archivo local `/tmp/the-store-images.tar`.
- Copia el tar a `/tmp/the-store-images.tar` en cada nodo.
- Importa las imagenes con `k3s ctr images import`.
- Ejecuta la importacion solo si falta alguna imagen esperada.
- Verifica las cinco imagenes `the-store-*` en cada nodo para evitar `ImagePullBackOff`.

Archivos implementados:

- `scripts/export-images.sh`
- `infra/ansible/roles/the_store_images/defaults/main.yml`
- `infra/ansible/roles/the_store_images/tasks/main.yml`
- `infra/ansible/playbooks/deploy-store.yml`

Desde la raiz del repo, exportar las imagenes:

```bash
bash scripts/export-images.sh
```

Luego importar en todos los nodos K3s:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml --tags images
```

Si se usa otra ubicacion para el tar:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml --tags images -e the_store_images_local_archive=/ruta/the-store-images.tar
```

Validacion esperada:

```bash
vagrant ssh k3s-control -c 'sudo k3s ctr images list | grep the-store'
vagrant ssh k3s-worker-1 -c 'sudo k3s ctr images list | grep the-store'
vagrant ssh k3s-worker-2 -c 'sudo k3s ctr images list | grep the-store'
```

## Fase 9: Deploy de The Store

El rol `the_store_deploy` despliega la aplicacion sobre el cluster K3s ya operativo:

- Crea el namespace `the-store` si no existe.
- Copia `dist/kubernetes.yaml` al Control Plane.
- Aplica los manifiestos con `kubectl apply -n the-store`.
- Mantiene persistencia `in-memory` segun el alcance del POC.
- Espera deployments `Available` y pods `Ready`.
- Verifica los deployments `catalog`, `carts`, `checkout`, `orders` y `ui`.
- Valida el Ingress `ui` con host `localhost` y clase `nginx`.
- Prueba HTTP por `http://192.168.56.10/` enviando `Host: localhost`.
- Configura `checkout` con `RETAIL_CHECKOUT_ENDPOINTS_ORDERS=http://orders` para que la orden final use el servicio `orders` real.

Nota: el Secret vacio `orders-rabbitmq` se omitio del manifiesto local porque el POC usa mensajeria `in-memory` y ese recurso no es referenciado por el deployment `orders`.

Archivos implementados:

- `infra/ansible/roles/the_store_deploy/defaults/main.yml`
- `infra/ansible/roles/the_store_deploy/tasks/main.yml`
- `infra/ansible/playbooks/deploy-store.yml`
- `dist/kubernetes.yaml`

Desde `infra/ansible`:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml --tags deploy
```

Validacion esperada:

```bash
kubectl --kubeconfig infra/kubeconfig get pods -n the-store -o wide
kubectl --kubeconfig infra/kubeconfig get svc -n the-store
kubectl --kubeconfig infra/kubeconfig get ingress -n the-store
curl -H 'Host: localhost' http://192.168.56.10/
```

## Fase 10: Validacion funcional de The Store

La fase 10 valida que la aplicacion funcione de punta a punta, no solo que los pods esten `Running`.

El script `scripts/validate-store.sh` ejecuta este flujo por HTTP contra el Ingress:

- abre la home;
- valida la topologia de servicios `catalog`, `carts`, `checkout` y `orders`;
- valida el catalogo;
- entra al detalle de un producto;
- agrega el producto al carrito;
- completa shipping, delivery y payment;
- confirma la orden final.

Desde la raiz del repo:

```bash
bash scripts/validate-store.sh
```

Valores por defecto:

- URL: `http://192.168.56.10`
- Host header: `localhost`

Si se cambia el host del Ingress o el endpoint:

```bash
bash scripts/validate-store.sh --url http://192.168.56.10 --host localhost
```

Logs utiles para evidenciar comunicacion entre servicios:

```bash
kubectl --kubeconfig infra/kubeconfig logs -n the-store deploy/ui --tail=100
kubectl --kubeconfig infra/kubeconfig logs -n the-store deploy/catalog --tail=100
kubectl --kubeconfig infra/kubeconfig logs -n the-store deploy/carts --tail=100
kubectl --kubeconfig infra/kubeconfig logs -n the-store deploy/checkout --tail=100
kubectl --kubeconfig infra/kubeconfig logs -n the-store deploy/orders --tail=100
```

## Referencia principal

El plan detallado esta en `docs/plan-ejecucion-k3s-the-store.md`.
