# How-to: K3s multi-nodo para The Store

Esta es la guia principal para levantar el POC de Redes desde cero. El objetivo es correr The Store sobre un cluster K3s local con Vagrant + Ansible.

> IMPORTANTE: para este POC **no** uses el flujo `local.sh`/Kind. Ese flujo pertenece al proyecto base (queda al final del README solo como referencia historica). El camino del TPE es **este** documento: Vagrant + Ansible + K3s.

## Como usar esta guia

- Copia y ejecuta primero la seccion **Correr todo desde cero**.
- Ejecuta los comandos desde la raiz del repositorio, salvo que el bloque diga explicitamente `cd infra` o `cd infra/ansible`.
- Si un paso falla, no sigas con el siguiente: anda a **Troubleshooting basico** y valida ese punto.
- El archivo `infra/kubeconfig` se genera durante el provisioning. No viene en Git porque tiene credenciales locales del cluster.
- Si estas en WSL, lee **Uso desde WSL** antes de correr Ansible.

## Prerrequisitos

Instalar y tener disponible en la terminal (links oficiales):

- VirtualBox: https://www.virtualbox.org/wiki/Downloads
- Vagrant: https://developer.hashicorp.com/vagrant/install
- Ansible: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
- Docker corriendo: https://docs.docker.com/get-docker/
- `kubectl`: https://kubernetes.io/docs/tasks/tools/
- `curl` y `bash` (vienen por defecto en Linux/macOS; en Windows usar WSL).

Chequeo rapido (Docker debe estar corriendo):

```bash
vagrant --version
VBoxManage --version
ansible --version
docker info | head -5
kubectl version --client
```

Requisitos de host:

- Sistemas soportados: Windows, Linux y macOS (Intel y Apple Silicon).
  - En macOS Apple Silicon se necesita VirtualBox 7.1 o superior; usa automaticamente la box ARM64.
  - En Windows, Ansible corre desde WSL (ver "Uso desde WSL" mas abajo).
- Al menos 6 GB de RAM libres para la topologia base.
- Al menos 8 GB de RAM libres si tambien vas a agregar `k3s-worker-3`.

El POC usa la red host-only `192.168.56.0/24`. Si otra herramienta ya usa esa red, Vagrant o Kubernetes pueden fallar hasta liberar esa red o ajustar las IPs del proyecto.

## Que se va a levantar

Topologia base:

| VM | Rol | IP privada | CPU | RAM |
| --- | --- | --- | --- | --- |
| `k3s-control` | Control Plane | `192.168.56.10` | 2 | 2048 MB |
| `k3s-worker-1` | Worker | `192.168.56.11` | 2 | 2048 MB |
| `k3s-worker-2` | Worker | `192.168.56.12` | 2 | 2048 MB |

Nodo opcional para la demo de crecimiento del cluster:

| VM | Rol | IP privada | CPU | RAM |
| --- | --- | --- | --- | --- |
| `k3s-worker-3` | Worker adicional | `192.168.56.13` | 2 | 2048 MB |

`k3s-worker-3` tiene `autostart: false`: no se levanta con el flujo base. Ademas vive en el grupo `ondemand_workers` del inventario (fuera de `k3s_cluster`), asi que mientras este apagado el flujo base lo ignora y **no produce errores ni avisos de "unreachable"**. Se agrega solo cuando quieras demostrar la fase 11 (escalado por carga).

## Correr todo desde cero

Parate en la raiz del repositorio. Una forma rapida de verificarlo:

```bash
ls README.md docs/how-to.md infra/Vagrantfile
```

### 1. Construir y exportar las imagenes

```bash
bash scripts/build-images.sh
bash scripts/export-images.sh
```

Esto construye estas imagenes locales:

- `the-store-catalog:latest`
- `the-store-cart:latest`
- `the-store-checkout:latest`
- `the-store-orders:latest`
- `the-store-ui:latest`

Luego las exporta a `/tmp/the-store-images.tar`, que Ansible va a copiar a los nodos K3s.

### 2. Levantar las VMs base

```bash
cd infra
vagrant validate
vagrant up k3s-control k3s-worker-1 k3s-worker-2
vagrant status
cd ..
```

El primer `vagrant up` puede tardar varios minutos porque descarga la box `bento/ubuntu-24.04` y crea las VMs.

### 3. Configurar K3s, workers, kubeconfig e Ingress

```bash
cd infra/ansible
ansible -i inventory/hosts.yml k3s_cluster -m ping
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
cd ../..
```

Este paso instala K3s, une los workers, exporta `infra/kubeconfig` e instala `ingress-nginx`.

### 4. Importar imagenes y desplegar The Store

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml
cd ../..
```

Este paso importa `/tmp/the-store-images.tar` en containerd de cada nodo y aplica `dist/kubernetes.yaml` en el namespace `the-store`.

### 5. Validar que todo quedo corriendo

```bash
export KUBECONFIG="$PWD/infra/kubeconfig"
bash scripts/status.sh
bash scripts/validate-store.sh
```

La validacion funcional debe terminar con:

```text
[store-validation] Functional validation completed successfully
```

### 6. Abrir la UI

La validacion del POC usa el Ingress con `Host: localhost`:

```bash
curl -H 'Host: localhost' http://192.168.56.10/
```

Para verla comoda en un navegador, usa port-forward desde la raiz del repo:

```bash
kubectl --kubeconfig infra/kubeconfig -n the-store port-forward svc/ui 8080:80
```

Mientras ese comando queda corriendo, abrir:

```text
http://localhost:8080
```

Para cortar el port-forward, presionar `Ctrl+C`.

## Uso desde WSL

El inventario normal usa la red host-only `192.168.56.0/24`. Si estas en WSL y Ansible no llega por SSH a las VMs, usa el inventario alternativo `inventory/hosts-wsl.yml`.

Desde PowerShell, en la carpeta `infra` del repo:

```powershell
$env:VAGRANT_EXPOSE_SSH="true"
vagrant up k3s-control k3s-worker-1 k3s-worker-2
```

Si las VMs ya estaban levantadas antes de activar `VAGRANT_EXPOSE_SSH`, ejecutar en PowerShell:

```powershell
$env:VAGRANT_EXPOSE_SSH="true"
vagrant reload
```

Desde WSL, en la carpeta `infra/ansible` del repo:

```bash
bash scripts/prepare-wsl-keys.sh
export NAT_SSH_HOST="$(awk '/nameserver/ {print $2; exit}' /etc/resolv.conf)"
ansible -i inventory/hosts-wsl.yml k3s_cluster -m ping
ansible-playbook -i inventory/hosts-wsl.yml playbooks/site.yml
ansible-playbook -i inventory/hosts-wsl.yml playbooks/deploy-store.yml
```

Importante: este modo resuelve SSH para Ansible. El kubeconfig generado apunta a `https://192.168.56.10:6443`; si WSL no tiene ruta a esa red, `kubectl` desde WSL no va a conectar. En ese caso valida con:

```bash
cd infra
vagrant ssh k3s-control -c 'sudo kubectl get nodes -o wide'
cd ..
```

O ejecuta `kubectl` desde Windows/macOS/Linux con acceso a la red host-only.

## Regenerar solo el kubeconfig

Si las VMs ya existen y solo falta `infra/kubeconfig`:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags kubeconfig
cd ../..
```

## Agregar `k3s-worker-3`

Este paso es opcional y sirve para demostrar que el cluster puede crecer sin recrear todo.

```bash
cd infra
vagrant up k3s-worker-3
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3
ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3 -e import_store_images=true --tags images
cd ../..
```

Demostrar scheduling sobre el nuevo nodo:

```bash
kubectl --kubeconfig infra/kubeconfig rollout restart deployment -n the-store
kubectl --kubeconfig infra/kubeconfig rollout status deployment -n the-store --timeout=300s
kubectl --kubeconfig infra/kubeconfig get pods -n the-store -o wide
```

## Referencia por fases

Las secciones siguientes explican que hace cada parte del flujo. No hace falta ejecutarlas una por una si ya corriste **Correr todo desde cero**.

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
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check
ansible-playbook -i inventory/hosts-wsl.yml playbooks/site.yml --syntax-check
cd ../..
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
cd "C:\ruta\a\Tp-final-redes\infra"
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

`k3s-worker-3` vive en el grupo `ondemand_workers` del inventario, fuera de `k3s_cluster`: el flujo base nunca lo toca y no falla aunque este apagado. En la fase 11, `add-worker.yml` lo agrega y lo valida explicitamente (la validacion incluye el nodo pasado en `add_worker_target`).

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
cd ../..
```

Si se usa otra ubicacion para el tar:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml --tags images -e the_store_images_local_archive=/ruta/the-store-images.tar
cd ../..
```

Validacion esperada:

```bash
cd infra
vagrant ssh k3s-control -c 'sudo k3s ctr images list | grep the-store'
vagrant ssh k3s-worker-1 -c 'sudo k3s ctr images list | grep the-store'
vagrant ssh k3s-worker-2 -c 'sudo k3s ctr images list | grep the-store'
cd ..
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

Desde la raiz del repo:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml --tags deploy
cd ../..
```

Validacion esperada desde la raiz del repo:

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

## Fase 11: Agregar un nuevo Worker

La fase 11 demuestra gestion basica del cluster: se agrega `k3s-worker-3` sin reinstalar el Control Plane ni recrear los workers existentes.

Desde la raiz del repo:

```bash
cd infra
vagrant up k3s-worker-3
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3
ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3 -e import_store_images=true --tags images
cd ../..
```

Como The Store usa imagenes locales importadas en containerd, el segundo comando importa el tar tambien en el nodo nuevo.

Nota: no usar `--limit k3s-worker-3`, porque `add-worker.yml` necesita pasar por el Control Plane para leer el token de join.

Validacion esperada desde la raiz del repo:

```bash
kubectl --kubeconfig infra/kubeconfig get nodes -o wide
kubectl --kubeconfig infra/kubeconfig wait --for=condition=Ready node/k3s-worker-3 --timeout=180s
```

Para demostrar que el nodo queda disponible para scheduling, se puede reiniciar los deployments de The Store desde la raiz del repo:

```bash
kubectl --kubeconfig infra/kubeconfig rollout restart deployment -n the-store
kubectl --kubeconfig infra/kubeconfig rollout status deployment -n the-store --timeout=300s
kubectl --kubeconfig infra/kubeconfig get pods -n the-store -o wide
```

## Troubleshooting basico

### Vagrant queda esperando SSH

Revisar estado de las VMs:

```bash
cd infra
vagrant status
```

Si una VM queda pausada, reanudarla:

```bash
vagrant resume
```

Si hace falta inspeccion visual en VirtualBox:

```bash
VAGRANT_GUI=true vagrant up k3s-control
```

### Ansible no llega por SSH

Validar conectividad:

```bash
cd infra/ansible
ansible -i inventory/hosts.yml k3s_cluster -m ping
```

Si se ejecuta desde WSL y no hay ruta a `192.168.56.0/24`, usar `inventory/hosts-wsl.yml` y preparar claves:

```bash
bash scripts/prepare-wsl-keys.sh
export NAT_SSH_HOST="$(awk '/nameserver/ {print $2; exit}' /etc/resolv.conf)"
ansible -i inventory/hosts-wsl.yml k3s_cluster -m ping
```

### `kubectl` desde WSL no conecta

El kubeconfig apunta a `https://192.168.56.10:6443`. Si WSL no tiene ruta a la red host-only, validar desde el Control Plane:

```bash
cd infra
vagrant ssh k3s-control -c 'sudo kubectl get nodes -o wide'
cd ..
```

O usar `kubectl` desde un host con acceso a `192.168.56.0/24`.

### Pods en `ImagePullBackOff`

The Store usa imagenes locales. Reexportar e importar:

```bash
bash scripts/export-images.sh
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml --tags images
cd ../..
```

Si el problema ocurre despues de agregar `worker-3`:

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3 -e import_store_images=true --tags images
cd ../..
```

### Ingress no responde

Validar controller e Ingress desde la raiz del repo:

```bash
kubectl --kubeconfig infra/kubeconfig get pods -n ingress-nginx
kubectl --kubeconfig infra/kubeconfig get ingress -n the-store -o wide
curl -H 'Host: localhost' http://192.168.56.10/
```

### Cambios de ConfigMap no impactan en pods

Kubernetes no reinicia pods automaticamente cuando cambia un ConfigMap consumido por `envFrom`. El rol `the_store_deploy` y `scripts/deploy-store.sh` reinician `checkout` si cambia su ConfigMap.

## Limpieza

Apagar VMs sin destruirlas:

```bash
cd infra
vagrant halt
```

Destruir el entorno completo:

```bash
cd infra
vagrant destroy -f
```

Limpiar artefactos locales opcionales:

Desde la raiz del repo:

```bash
rm -f /tmp/the-store-images.tar
rm -f infra/kubeconfig
```

## Evidencia final esperada

Comandos utiles para la defensa:

```bash
(cd infra && vagrant status)
kubectl --kubeconfig infra/kubeconfig get nodes -o wide
kubectl --kubeconfig infra/kubeconfig get pods -n the-store -o wide
kubectl --kubeconfig infra/kubeconfig get svc -n the-store
kubectl --kubeconfig infra/kubeconfig get ingress -n the-store -o wide
bash scripts/validate-store.sh
```

Resultados esperados:

- `k3s-control`, `k3s-worker-1`, `k3s-worker-2` y `k3s-worker-3` en `Ready`.
- Pods de The Store en `Running`.
- Al menos algun pod schedulado en `k3s-worker-3` despues del rollout de fase 11.
- Ingress `ui` publicado en `192.168.56.10` con host `localhost`.
- Validacion funcional final exitosa.

## Referencia principal

El plan detallado esta en `docs/plan-ejecucion-k3s-the-store.md`.
