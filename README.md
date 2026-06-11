# The Store sobre K3s multi-nodo (TPE Redes — Grupo 12)

Trabajo Práctico Especial de Redes de Información, tema **6. Despliegue y Gestión del Cluster
de Kubernetes**. Este repositorio levanta, de forma automatizada y reproducible, un clúster
**Kubernetes (K3s)** de **1 control plane + 2 workers** sobre **3 máquinas virtuales** y despliega
sobre él la aplicación de e-commerce **The Store**.

> Esta guía está pensada para que **cualquier persona, sin conocimiento previo de Kubernetes,
> Vagrant o Ansible**, pueda levantar todo desde cero copiando y pegando los comandos.
> Si algo falla en un paso, **no sigas al siguiente**: revisá [docs/how-to.md](docs/how-to.md)
> (guía detallada con troubleshooting).

---

## 1. ¿Qué hace cada herramienta?

No hace falta saber usarlas; el proyecto las orquesta por vos. Solo necesitás tenerlas instaladas.

| Herramienta | Para qué sirve en este TP |
|---|---|
| **VirtualBox** | Hipervisor: crea y corre las máquinas virtuales (las "computadoras" del clúster). |
| **Vagrant** | Crea esas VMs automáticamente a partir de un archivo (`infra/Vagrantfile`). |
| **Ansible** | Entra a las VMs por SSH y las configura: instala K3s, une los workers, abre puertos, instala el Ingress. |
| **K3s** | Una distribución liviana de **Kubernetes**, el orquestador que corre la aplicación. |
| **Ingress (ingress-nginx)** | La puerta de entrada HTTP/HTTPS que publica la app hacia afuera. |
| **Docker** | Construye las imágenes de los microservicios de The Store. |
| **kubectl** | El cliente de línea de comandos para hablar con el clúster (ver nodos, pods, etc.). |

---

## 2. Qué se va a levantar

Topología base (lo que crea el flujo normal):

| VM | Rol | IP privada | CPU | RAM |
|---|---|---|---|---|
| `k3s-control` | Control Plane | `192.168.56.10` | 2 | 2048 MB |
| `k3s-worker-1` | Worker | `192.168.56.11` | 2 | 2048 MB |
| `k3s-worker-2` | Worker | `192.168.56.12` | 2 | 2048 MB |

Nodo extra, **opcional**, solo para la demo de "agregar un worker" (sección 7):

| VM | Rol | IP privada | CPU | RAM |
|---|---|---|---|---|
| `k3s-worker-3` | Worker adicional | `192.168.56.13` | 2 | 2048 MB |

Parámetros de red del clúster: **Pod CIDR** `10.42.0.0/16`, **Service CIDR** `10.43.0.0/16`,
overlay **Flannel (VXLAN)**. SO de los nodos: **Ubuntu Server 24.04 LTS**. K3s `v1.35.5+k3s1`.

---

## 3. Requisitos

### Hardware / sistema operativo

- **Sistemas soportados:** Windows, Linux y macOS (Intel y **Apple Silicon**).
  - En **macOS Apple Silicon** se necesita **VirtualBox 7.1 o superior** (usa automáticamente la
    variante ARM64 de la box). Probado en Apple Silicon con VirtualBox 7.2.
  - En **Windows**, Ansible se ejecuta a través de **WSL** (ver [docs/how-to.md](docs/how-to.md), sección "Uso desde WSL").
- **RAM libre:** al menos **6 GB** para la topología base (8 GB si además agregás `k3s-worker-3`).
- **Red:** la subred `192.168.56.0/24` debe estar libre. Si otra herramienta ya la usa,
  liberala o ajustá las IPs en `infra/Vagrantfile` y el inventario.

### Software a instalar

Instalá estas herramientas (links oficiales):

| Software | Link de instalación |
|---|---|
| VirtualBox | https://www.virtualbox.org/wiki/Downloads |
| Vagrant | https://developer.hashicorp.com/vagrant/install |
| Ansible | https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html |
| Docker | https://docs.docker.com/get-docker/ |
| kubectl | https://kubernetes.io/docs/tasks/tools/ |

Verificá que todo esté disponible en tu terminal (y que Docker esté corriendo):

```bash
vagrant --version
VBoxManage --version
ansible --version
docker info | head -5      # si falla, abrí Docker Desktop / iniciá el servicio
kubectl version --client
```

---

## 4. Correr todo desde cero

> Ejecutá los comandos **desde la raíz del repositorio**, salvo cuando el bloque diga `cd ...`.
> Para confirmar que estás en la raíz: `ls README.md infra/Vagrantfile`.

### Paso 1 — Construir y exportar las imágenes de The Store

```bash
bash scripts/build-images.sh
bash scripts/export-images.sh
```

Construye las 5 imágenes locales (`the-store-catalog`, `cart`, `checkout`, `orders`, `ui`) y las
empaqueta en `/tmp/the-store-images.tar`, que Ansible copiará a cada nodo.

### Paso 2 — Crear las 3 máquinas virtuales

```bash
cd infra
vagrant up k3s-control k3s-worker-1 k3s-worker-2
cd ..
```

La primera vez puede tardar varios minutos (descarga la box de Ubuntu y crea las VMs).
> No uses `vagrant up` "a secas": nombrá las 3 VMs como arriba para no levantar también `k3s-worker-3`.

### Paso 3 — Configurar el clúster K3s con Ansible

```bash
cd infra/ansible
ansible -i inventory/hosts.yml k3s_cluster -m ping
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
cd ../..
```

Instala K3s en el control plane, une los 2 workers con el token del clúster, abre los puertos en el
firewall, exporta el archivo `infra/kubeconfig` (credenciales locales) e instala `ingress-nginx`.

### Paso 4 — Desplegar The Store sobre el clúster

```bash
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml
cd ../..
```

Importa las imágenes en cada nodo y aplica los manifiestos `dist/kubernetes.yaml` en el namespace `the-store`.

### Paso 5 — Validar que todo quedó corriendo

```bash
export KUBECONFIG="$PWD/infra/kubeconfig"   # le dice a kubectl dónde están las credenciales del clúster
bash scripts/status.sh
bash scripts/validate-store.sh
```

La validación funcional debe terminar con:

```text
[store-validation] Functional validation completed successfully
```

---

## 5. Abrir la app en el navegador

La aplicación se publica a través del Ingress con el host `localhost`. Dos formas de verla:

**Opción A — Port-forward (la más simple):** dejá este comando corriendo en una terminal:

```bash
kubectl --kubeconfig infra/kubeconfig -n the-store port-forward svc/ui 8080:80
```

y abrí **http://localhost:8080** en el navegador. Para cortarlo: `Ctrl+C`.

**Opción B — Verificar el Ingress directamente** (la ruta real de producción, vía `ingress-nginx`):

```bash
curl -H 'Host: localhost' http://192.168.56.10/
```

Debe responder `HTTP 200` con el HTML de la home.

---

## 6. ¿Cómo sé que funcionó? (validación)

```bash
export KUBECONFIG="$PWD/infra/kubeconfig"
kubectl get nodes -o wide                 # los 3 nodos en estado Ready
kubectl get pods -n the-store -o wide     # los 5 servicios en Running
bash scripts/validate-store.sh            # recorrido funcional completo (catálogo → carrito → orden)
```

Resultado esperado: nodos `Ready`, pods `Running`, y la validación funcional termina con éxito.

---

## 7. Demo opcional: agregar un worker para soportar más carga

Demuestra la gestión/crecimiento del clúster (caso de uso 3 de la pre-entrega): el clúster
arranca con 3 nodos y `k3s-worker-3` se suma **solo** como respuesta a carga. Por eso este nodo
arranca apagado y está en un grupo aparte del inventario (`ondemand_workers`): el flujo base de
las secciones 4–6 lo ignora y **no da error aunque esté apagado**.

La idea: bajo carga, escalás `ui` (que tiene anti-afinidad "una réplica por nodo"); con 3 nodos
la réplica extra queda **`Pending`**, y al agregar `k3s-worker-3` esa réplica se programa ahí y
**entra a la rotación de balanceo** del Service `ui`. Es escalado **manual**, no autoscaling.

Pasos resumidos (guía completa en
[docs/how-to.md](docs/how-to.md), sección "Agregar `k3s-worker-3` para soportar más carga"):

```bash
# (1) Escalar ui -> con 3 nodos queda 1 réplica Pending (anti-afinidad por nodo):
kubectl --kubeconfig infra/kubeconfig -n the-store scale deployment/ui --replicas=4

# (2) Agregar el nodo:
cd infra && vagrant up k3s-worker-3 && cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3
ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3 -e import_store_images=true --tags images
cd ../..

# (3) Evidencia: la réplica de ui ahora corre en k3s-worker-3 y es endpoint del Service:
kubectl --kubeconfig infra/kubeconfig -n the-store get pods -l app.kubernetes.io/name=ui -o wide
kubectl --kubeconfig infra/kubeconfig -n the-store get endpointslices -l kubernetes.io/service-name=ui -o wide

# (4) Scale-in: cuando baja la carga, se reduce ui y se retira el nodo (vuelve al baseline de 3):
kubectl --kubeconfig infra/kubeconfig -n the-store scale deployment/ui --replicas=1
kubectl --kubeconfig infra/kubeconfig drain k3s-worker-3 --ignore-daemonsets --delete-emptydir-data
kubectl --kubeconfig infra/kubeconfig delete node k3s-worker-3
(cd infra && vagrant halt k3s-worker-3)
```

---

## 8. Limpieza

```bash
cd infra
vagrant halt        # apaga las VMs sin borrarlas
# o
vagrant destroy -f  # elimina todo el entorno
cd ..
```

---

## 9. Documentación del proyecto

- **Guía operativa detallada (con troubleshooting):** [docs/how-to.md](docs/how-to.md)
- Plan de ejecución por fases: [docs/plan-ejecucion-k3s-the-store.md](docs/plan-ejecucion-k3s-the-store.md)
- Evidencia de validación final: [docs/validacion-final.md](docs/validacion-final.md)
- Guion de la presentación: [docs/guion-presentacion.md](docs/guion-presentacion.md)
- Infraestructura (Vagrant + Ansible): [infra/README.md](infra/README.md) · [infra/ansible/README.md](infra/ansible/README.md)

---

## Arquitectura de The Store

The Store es una plataforma de e-commerce construida con microservicios en distintos lenguajes:

![Architecture](/docs/images/architecture.png)

| Servicio | Lenguaje | Descripción |
|---------|----------|-------------|
| [UI](./src/ui/) | Java (Spring Boot) | Interfaz web (storefront). |
| [Catalog](./src/catalog/) | Go | API del catálogo de productos. |
| [Cart](./src/cart/) | Java (Spring Boot) | Carrito de compras. |
| [Orders](./src/orders/) | Java (Spring Boot) | Procesamiento de órdenes. |
| [Checkout](./src/checkout/) | Node.js (NestJS) | Orquestación de checkout y pago. |

---

## Flujo original del proyecto base con Kind — ⚠️ NO usar para el TPE

> Esta sección pertenece al proyecto base original (The Store) y usa **Kind** + el script
> `local.sh`. **No es el camino del TPE de Redes** y no se usa para la entrega. Para el TP, seguí
> las secciones 1–8 de arriba (Vagrant + Ansible + K3s). Se conserva solo como referencia histórica.

<details>
<summary>Ver flujo original con Kind / local.sh</summary>

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) running
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) installed
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed

### Cluster Management

```bash
./local.sh create-cluster     # crea el clúster Kind y despliega los servicios
./local.sh rebuild-cluster    # recrea el clúster
./local.sh delete-cluster     # borra el clúster
./local.sh status             # estado del clúster
./local.sh reload-images      # solo reconstruye y carga imágenes
```

Tras `./local.sh create-cluster`, The Store queda en **http://localhost**.

### Testing

```bash
./local.sh e2e-test                        # tests e2e sobre el clúster existente
./local.sh create-cluster --skip-tests     # crear sin correr tests
./local.sh load-test                       # tests de carga
```

</details>

---

**The Store** — Built with ❤️ for modern e-commerce
