# Plan de ejecucion: K3s multi-nodo para The Store

## 1. Proposito del documento

Este documento define un plan detallado, incremental y verificable para implementar el POC aprobado por la catedra para el Trabajo Practico Especial de Redes de Informacion.

El objetivo no es redisenar The Store, sino construir una plataforma local reproducible para desplegarla sobre Kubernetes, cumpliendo estrictamente la preentrega aprobada:

- Vagrant para aprovisionar maquinas virtuales.
- Ansible para automatizar configuracion e instalacion.
- K3s como distribucion Kubernetes.
- Topologia inicial de 1 Control Plane y 2 Workers.
- Red privada `192.168.56.0/24`.
- Ubuntu Server 24.04 LTS en los nodos.
- Flannel VXLAN como red overlay.
- Ingress Controller para exponer The Store por HTTP/HTTPS.
- Despliegue de The Store sobre el cluster.
- Demostracion de gestion basica agregando un nuevo Worker sin reinstalar el entorno.

## 2. Alcance contractual

La preentrega funciona como contrato. Por lo tanto, las decisiones tecnicas deben mantenerse dentro del siguiente alcance.

| Area | Compromiso aprobado | Implicancia de implementacion |
| --- | --- | --- |
| Infraestructura | Vagrant aprovisiona 3 VMs Ubuntu Server 24.04 LTS | Se debe crear un `Vagrantfile` con 1 control plane y 2 workers iniciales |
| Red privada | `192.168.56.0/24` | Las VMs deben tener IPs fijas dentro de esa red |
| Control Plane | `192.168.56.10` | K3s server corre en este nodo |
| Worker 1 | `192.168.56.11` | K3s agent unido al cluster |
| Worker 2 | `192.168.56.12` | K3s agent unido al cluster |
| Pod CIDR | `10.42.0.0/16` | K3s debe usar ese rango para pods |
| Service CIDR | `10.43.0.0/16` | K3s debe usar ese rango para services |
| Overlay | Flannel VXLAN | Mantener Flannel, que es el CNI por defecto de K3s |
| Puertos | SSH `22`, API `6443`, Flannel UDP `8472`, Ingress `80/443` | Firewall y documentacion deben contemplar estos puertos |
| Validacion | Nodos `Ready`, pods `Running`, servicios accesibles, Ingress funcional | Se deben incluir comandos de verificacion |
| Gestion | Alta de un Worker por inventario Ansible y re-ejecucion del playbook | El flujo debe permitir sumar un nodo sin reconstruir el cluster |

Fuera de alcance, porque asi fue declarado en la preentrega:

- Alta disponibilidad del Control Plane.
- Autoscaling.
- Upgrades entre versiones.
- Almacenamiento persistente distribuido.
- Despliegue en cloud publica.

## 3. Lectura de The Store

The Store es una aplicacion de ecommerce basada en microservicios. El repo ya trae Dockerfiles, manifiestos Kubernetes, pruebas E2E y generador de carga.

| Servicio | Tecnologia | Rol | Imagen esperada |
| --- | --- | --- | --- |
| `ui` | Java Spring Boot | Frontend web y agregador de llamadas a backend | `the-store-ui:latest` |
| `catalog` | Go | API de catalogo de productos | `the-store-catalog:latest` |
| `cart` | Java Spring Boot | Carrito de compras | `the-store-cart:latest` |
| `orders` | Java Spring Boot | Gestion de ordenes | `the-store-orders:latest` |
| `checkout` | Node.js NestJS | Orquestacion del checkout | `the-store-checkout:latest` |

El manifiesto principal es `dist/kubernetes.yaml`. Actualmente define:

- `ServiceAccount`, `ConfigMap`, `Secret`, `Service` y `Deployment` para cada servicio.
- 1 replica por deployment.
- Servicios internos `ClusterIP`.
- Persistencia `in-memory` para simplificar el POC.
- `Ingress` para exponer `ui`.
- Imagenes locales con tag `latest`.
- `imagePullPolicy: IfNotPresent`.

El script `local.sh` sirve como referencia para build, deploy, pruebas E2E y load test, pero su parte de cluster usa Kind. Para este TP, Kind no debe ser la base de la arquitectura final porque la preentrega aprobada exige Vagrant + Ansible + K3s sobre VMs.

## 4. Arquitectura objetivo

### 4.1 Topologia inicial

| Nodo | Rol | IP privada | Sistema operativo | Funcion |
| --- | --- | --- | --- | --- |
| `k3s-control` | Control Plane | `192.168.56.10` | Ubuntu Server 24.04 LTS | API Server, scheduler, controller manager, datastore embebido de K3s |
| `k3s-worker-1` | Worker | `192.168.56.11` | Ubuntu Server 24.04 LTS | Ejecucion de pods |
| `k3s-worker-2` | Worker | `192.168.56.12` | Ubuntu Server 24.04 LTS | Ejecucion de pods |

### 4.2 Topologia luego de la demo de gestion

| Nodo | Rol | IP privada | Sistema operativo | Funcion |
| --- | --- | --- | --- | --- |
| `k3s-worker-3` | Worker | `192.168.56.13` | Ubuntu Server 24.04 LTS | Nodo agregado por inventario Ansible y re-ejecucion del playbook |

### 4.3 Flujo logico

1. El host ejecuta Vagrant.
2. Vagrant crea las VMs en la red privada `192.168.56.0/24`.
3. El host ejecuta Ansible contra las VMs.
4. Ansible prepara sistema operativo, red, firewall y dependencias.
5. Ansible instala K3s server en `k3s-control`.
6. Ansible obtiene automaticamente el token de join.
7. Ansible instala K3s agent en los workers.
8. Se valida que todos los nodos esten `Ready`.
9. Se instalan o habilitan los componentes de Ingress.
10. Se distribuyen las imagenes locales de The Store a los nodos.
11. Se despliega The Store en namespace `the-store`.
12. Se valida acceso HTTP por Ingress.
13. Se agrega un nuevo worker y se demuestra que el cluster lo incorpora.

## 5. Estrategia de implementacion de menos a mas

### Fase 0: Preparacion del workspace

Objetivo: ordenar los artefactos propios del TP sin mezclar la implementacion con el codigo fuente original de The Store.

Tareas:

- Crear estructura `infra/` para Vagrant y Ansible.
- Crear estructura `scripts/` para comandos repetibles de build, import, deploy y validacion.
- Crear documentacion en `docs/`.
- Mantener `dist/kubernetes.yaml` como base de despliegue de The Store.

Archivos esperados:

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
scripts/
  build-images.sh
  export-images.sh
  deploy-store.sh
  status.sh
docs/
  how-to.md
  plan-ejecucion-k3s-the-store.md
```

Criterio de aceptacion:

```bash
rg --files infra scripts docs
```

Debe mostrar los archivos del TP de forma ordenada.

### Fase 1: Build local de imagenes de The Store

Objetivo: construir las cinco imagenes que consume `dist/kubernetes.yaml`.

Tareas:

- Reutilizar la lista de servicios de `local.sh`: `catalog cart checkout orders ui`.
- Crear `scripts/build-images.sh`.
- Ejecutar `docker build` en cada directorio `src/<servicio>`.
- Etiquetar exactamente como espera el manifiesto:
  - `the-store-catalog:latest`
  - `the-store-cart:latest`
  - `the-store-checkout:latest`
  - `the-store-orders:latest`
  - `the-store-ui:latest`

Comando esperado:

```bash
bash scripts/build-images.sh
```

Criterio de aceptacion:

```bash
docker images | rg 'the-store-(catalog|cart|checkout|orders|ui)'
```

Riesgo principal:

- Los Dockerfiles descargan dependencias desde internet. Conviene hacer esta fase temprano, antes de la demo, para dejar las imagenes construidas.

### Fase 2: Vagrant inicial con 3 VMs

Objetivo: cumplir la parte de infraestructura del contrato.

Tareas:

- Crear `infra/Vagrantfile`.
- Definir 3 VMs Ubuntu Server 24.04 LTS.
- Asignar IPs fijas:
  - `k3s-control`: `192.168.56.10`
  - `k3s-worker-1`: `192.168.56.11`
  - `k3s-worker-2`: `192.168.56.12`
- Configurar recursos razonables por VM.
- Mantener nombres de host claros.

Sizing recomendado inicial:

| Nodo | CPU | RAM |
| --- | --- | --- |
| `k3s-control` | 2 | 2048 MB |
| `k3s-worker-1` | 2 | 2048 MB |
| `k3s-worker-2` | 2 | 2048 MB |

Comando esperado:

```bash
cd infra
vagrant up
```

Criterios de aceptacion:

```bash
vagrant status
vagrant ssh k3s-control -c 'hostname -I'
vagrant ssh k3s-worker-1 -c 'hostname -I'
vagrant ssh k3s-worker-2 -c 'hostname -I'
```

Debe verse cada IP esperada dentro de `192.168.56.0/24`.

### Fase 3: Inventario Ansible y rol comun

Objetivo: preparar los nodos de forma repetible e idempotente.

Tareas:

- Crear `infra/ansible/inventory/hosts.yml`.
- Definir grupos:
  - `control_plane`
  - `workers`
  - `k3s_cluster`
- Crear rol `common`.
- Instalar dependencias base:
  - `curl`
  - `ca-certificates`
  - `iptables`
  - `containerd` si hiciera falta para herramientas auxiliares
  - utilidades de diagnostico como `jq`, `net-tools` o `iproute2`
- Configurar parametros de kernel necesarios para Kubernetes.
- Asegurar conectividad SSH.
- Preparar reglas de firewall o documentarlas si se usa firewall deshabilitado en laboratorio.

Inventario esperado:

```yaml
all:
  children:
    control_plane:
      hosts:
        k3s-control:
          ansible_host: 192.168.56.10
    workers:
      hosts:
        k3s-worker-1:
          ansible_host: 192.168.56.11
        k3s-worker-2:
          ansible_host: 192.168.56.12
    k3s_cluster:
      children:
        control_plane:
        workers:
```

Comando esperado:

```bash
ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/site.yml
```

Criterios de aceptacion:

- El playbook termina sin errores.
- El playbook puede ejecutarse una segunda vez sin cambios destructivos.
- Los nodos responden por SSH.

### Fase 4: Instalacion de K3s server en el Control Plane

Objetivo: levantar el plano de control de Kubernetes en `192.168.56.10`.

Tareas:

- Crear rol `k3s_server`.
- Instalar K3s server en `k3s-control`.
- Fijar parametros compatibles con la preentrega:
  - `--cluster-cidr=10.42.0.0/16`
  - `--service-cidr=10.43.0.0/16`
  - Flannel VXLAN como backend
- Asegurar que el API Server escuche en `192.168.56.10`.
- Guardar kubeconfig para usar `kubectl` desde el host o desde el control plane.
- Obtener token de join desde `/var/lib/rancher/k3s/server/node-token`.

Comandos de validacion:

```bash
vagrant ssh k3s-control -c 'sudo kubectl get nodes'
vagrant ssh k3s-control -c 'sudo kubectl cluster-info'
vagrant ssh k3s-control -c 'sudo systemctl status k3s --no-pager'
```

Criterio de aceptacion:

- `k3s-control` aparece `Ready`.
- El API Server responde en puerto `6443`.

### Fase 5: Union de Workers con token automatico

Objetivo: unir los workers al cluster sin pasos manuales fragiles.

Tareas:

- Crear rol `k3s_agent`.
- Desde Ansible, leer el token generado por el control plane.
- Instalar K3s agent en `k3s-worker-1` y `k3s-worker-2`.
- Configurar cada agent con:
  - `K3S_URL=https://192.168.56.10:6443`
  - `K3S_TOKEN=<token obtenido automaticamente>`
- Esperar hasta que los nodos aparezcan en Kubernetes.

Comandos de validacion:

```bash
vagrant ssh k3s-control -c 'sudo kubectl get nodes -o wide'
```

Criterio de aceptacion:

Debe verse:

```text
k3s-control    Ready
k3s-worker-1   Ready
k3s-worker-2   Ready
```

Esto cubre el caso de uso 1: "Zero to Kube".

### Fase 6: Kubeconfig para operacion desde el host

Objetivo: facilitar la demo y reducir friccion operativa.

Tareas:

- Copiar kubeconfig desde `/etc/rancher/k3s/k3s.yaml`.
- Reemplazar `127.0.0.1` por `192.168.56.10`.
- Guardarlo como `infra/kubeconfig`.
- Documentar uso con `KUBECONFIG`.

Comandos esperados:

```bash
export KUBECONFIG="$PWD/infra/kubeconfig"
kubectl get nodes -o wide
```

Criterio de aceptacion:

- Se puede operar el cluster desde el host.
- `kubectl get nodes` no requiere entrar por SSH al control plane.

### Fase 7: Ingress Controller

Objetivo: exponer The Store por HTTP/HTTPS como indica la preentrega.

Tareas:

- Decidir una de estas dos opciones y documentarla:
  - Usar Traefik incluido por defecto en K3s.
  - Deshabilitar Traefik e instalar `ingress-nginx`.
- Recomendacion: instalar `ingress-nginx`, porque el manifiesto de The Store usa clase `nginx`.
- Crear rol `ingress`.
- Aplicar manifiestos de `ingress-nginx`.
- Validar que el controller quede `Ready`.
- Confirmar exposicion por puerto `80` y dejar preparado `443` aunque el POC use HTTP para la demo principal.

Comandos de validacion:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass
```

Criterio de aceptacion:

- Existe una `IngressClass` compatible con `nginx`.
- El controller esta listo.
- El host puede llegar a `192.168.56.10:80`.

### Fase 8: Distribucion de imagenes a K3s

Objetivo: resolver que las imagenes construidas en el host no existen automaticamente dentro de las VMs.

Tareas:

- Crear `scripts/export-images.sh`.
- Exportar las imagenes:

```bash
docker save \
  the-store-catalog:latest \
  the-store-cart:latest \
  the-store-checkout:latest \
  the-store-orders:latest \
  the-store-ui:latest \
  -o /tmp/the-store-images.tar
```

- Copiar el tar a los nodos con Ansible o `vagrant upload`.
- Importar en containerd de K3s:

```bash
sudo k3s ctr images import /tmp/the-store-images.tar
```

- Ejecutar import al menos en todos los nodos worker para evitar `ImagePullBackOff` si el scheduler coloca pods alli.

Alternativa valida:

- Levantar un registry local accesible desde `192.168.56.0/24` y configurar K3s para usarlo.

Recomendacion para este TP:

- Usar `docker save` + import con Ansible. Es mas simple, auditable y suficiente para una demo local.

Criterio de aceptacion:

```bash
vagrant ssh k3s-worker-1 -c 'sudo k3s ctr images list | grep the-store'
vagrant ssh k3s-worker-2 -c 'sudo k3s ctr images list | grep the-store'
```

### Fase 9: Deploy de The Store

Objetivo: desplegar la aplicacion sobre el cluster K3s ya operativo.

Tareas:

- Crear namespace `the-store`.
- Aplicar `dist/kubernetes.yaml`.
- Mantener persistencia `in-memory` para respetar el POC y evitar agregar bases externas no comprometidas.
- Mantener el Ingress con host `localhost` y documentar acceso usando header `Host: localhost`.
- Configurar `checkout` con `RETAIL_CHECKOUT_ENDPOINTS_ORDERS=http://orders` para que la orden final use el servicio `orders` real.

Comandos esperados:

```bash
kubectl create namespace the-store
kubectl apply -f dist/kubernetes.yaml -n the-store
kubectl wait --namespace the-store --for=condition=available deployments --timeout=300s --all
kubectl wait --namespace the-store --for=condition=ready pods --timeout=300s --all
```

Criterios de aceptacion:

```bash
kubectl get pods -n the-store -o wide
kubectl get svc -n the-store
kubectl get ingress -n the-store
curl -H 'Host: localhost' http://192.168.56.10/
```

Esto cubre el caso de uso 2: despliegue de la aplicacion, pods `Running`, servicios accesibles e Ingress funcional.

### Fase 10: Validacion funcional de la aplicacion

Objetivo: demostrar que no solo hay pods corriendo, sino que The Store funciona.

Validaciones minimas:

- Abrir la UI por navegador.
- Ver catalogo.
- Entrar a un producto.
- Agregar producto al carrito.
- Pasar por checkout.
- Confirmar que `ui` se comunica con `catalog`, `carts`, `checkout` y `orders`.

Comandos utiles:

```bash
kubectl logs -n the-store deploy/ui --tail=100
kubectl logs -n the-store deploy/catalog --tail=100
kubectl logs -n the-store deploy/carts --tail=100
kubectl logs -n the-store deploy/checkout --tail=100
kubectl logs -n the-store deploy/orders --tail=100
```

Validacion automatizada opcional:

```bash
bash scripts/validate-store.sh
```

Load test opcional:

- Queda como extra tecnico fuera del foco principal.
- Si se ejecuta, ajustar previamente el endpoint/host de Ingress para que el generador llegue con el host esperado.

Nota:

- El load test puede mostrarse como extra tecnico, pero no debe desplazar el foco del TP, que es despliegue y gestion del cluster.

### Fase 11: Demo de gestion basica y escalabilidad

Objetivo: cumplir el tercer caso de uso aprobado: agregar un nuevo Worker al cluster mediante inventario Ansible y re-ejecucion del playbook.

Tareas:

- Agregar `k3s-worker-3` al `Vagrantfile`.
- Asignar IP `192.168.56.13`.
- Agregar `k3s-worker-3` al grupo `workers` del inventario Ansible.
- Ejecutar:

```bash
cd infra
vagrant up k3s-worker-3
cd ..
ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/site.yml
```

Validacion:

```bash
kubectl get nodes -o wide
```

Criterio de aceptacion:

Debe verse:

```text
k3s-control    Ready
k3s-worker-1   Ready
k3s-worker-2   Ready
k3s-worker-3   Ready
```

Validacion adicional:

```bash
kubectl get pods -n the-store -o wide
kubectl rollout restart deployment -n the-store
kubectl get pods -n the-store -o wide
```

La validacion adicional permite mostrar que el nuevo nodo queda disponible para scheduling. No hace falta prometer autoscaling porque esta fuera de alcance.

### Fase 12: How-to final y guion de presentacion

Objetivo: entregar material que permita reproducir la implementacion y defenderla oralmente.

Documentos esperados:

- `docs/how-to.md`: guia paso a paso para instalar, desplegar, validar y agregar worker.
- `docs/plan-ejecucion-k3s-the-store.md`: este plan.
- Slides de presentacion.

Contenido minimo del how-to:

1. Prerrequisitos del host.
2. Como levantar VMs.
3. Como ejecutar Ansible.
4. Como configurar `KUBECONFIG`.
5. Como construir e importar imagenes.
6. Como desplegar The Store.
7. Como validar nodos, pods, services e Ingress.
8. Como agregar un nuevo worker.
9. Troubleshooting basico.
10. Como limpiar el entorno.

Guion de demo recomendado:

1. Mostrar contrato de arquitectura.
2. Ejecutar o mostrar `vagrant status`.
3. Ejecutar `kubectl get nodes -o wide`.
4. Mostrar pods de The Store distribuidos en el cluster.
5. Abrir UI por Ingress.
6. Mostrar flujo funcional breve de compra.
7. Agregar `worker-3`.
8. Re-ejecutar Ansible.
9. Mostrar `kubectl get nodes -o wide` con el nuevo nodo.
10. Explicar limites: no HA, no autoscaling, no storage distribuido, no cloud.

## 6. Artefactos a implementar

### Infraestructura

```text
infra/Vagrantfile
```

Responsabilidad:

- Definir VMs.
- Definir IPs.
- Definir recursos.
- Permitir crear inicialmente 3 nodos y luego sumar `worker-3`.

### Automatizacion

```text
infra/ansible/inventory/hosts.yml
infra/ansible/playbooks/site.yml
infra/ansible/playbooks/add-worker.yml
infra/ansible/playbooks/deploy-store.yml
infra/ansible/roles/common/
infra/ansible/roles/k3s_server/
infra/ansible/roles/k3s_agent/
infra/ansible/roles/k3s_cluster_validation/
infra/ansible/roles/k3s_kubeconfig/
infra/ansible/roles/ingress/
infra/ansible/roles/the_store_images/
infra/ansible/roles/the_store_deploy/
```

Responsabilidad:

- Preparar nodos.
- Instalar K3s.
- Unir workers.
- Instalar Ingress.
- Distribuir imagenes.
- Desplegar The Store.
- Agregar `worker-3` sin reinstalar el cluster.
- Mantener idempotencia.

### Scripts de apoyo

```text
scripts/build-images.sh
scripts/export-images.sh
scripts/deploy-store.sh
scripts/status.sh
scripts/validate-store.sh
```

Responsabilidad:

- Reducir errores durante la demo.
- Hacer repetibles los pasos.
- Mantener comandos largos fuera de la presentacion oral.

### Documentacion

```text
docs/how-to.md
docs/guion-presentacion.md
docs/validacion-final.md
```

Responsabilidad:

- Explicar como reproducir el POC.
- Documentar problemas esperables y solucion.
- Dejar evidencia de cierre y guion de demo.

## 7. Validaciones obligatorias

### Cluster

```bash
kubectl --kubeconfig infra/kubeconfig get nodes -o wide
kubectl --kubeconfig infra/kubeconfig cluster-info
kubectl --kubeconfig infra/kubeconfig get pods -A
```

Debe probar:

- API Server funcional.
- 1 control plane y 2 workers iniciales.
- 1 worker adicional `k3s-worker-3` en la demo de fase 11.
- Todos los nodos `Ready`.

### Red

```bash
kubectl --kubeconfig infra/kubeconfig get pods -n kube-system -o wide
kubectl --kubeconfig infra/kubeconfig get nodes -o wide
```

Debe probar:

- Pods con IPs del rango `10.42.0.0/16`.
- Services con IPs del rango `10.43.0.0/16`.
- Comunicacion entre nodos.

### The Store

```bash
kubectl --kubeconfig infra/kubeconfig get deploy -n the-store
kubectl --kubeconfig infra/kubeconfig get pods -n the-store -o wide
kubectl --kubeconfig infra/kubeconfig get svc -n the-store
kubectl --kubeconfig infra/kubeconfig get ingress -n the-store -o wide
curl -H 'Host: localhost' http://192.168.56.10/
bash scripts/validate-store.sh
```

Debe probar:

- Deployments disponibles.
- Pods `Running`.
- Services internos creados.
- Ingress funcional.
- UI accesible.
- Flujo funcional completo validado.

### Gestion

```bash
kubectl --kubeconfig infra/kubeconfig get nodes -o wide
```

Antes de agregar el worker:

```text
k3s-control
k3s-worker-1
k3s-worker-2
```

Despues de agregar el worker:

```text
k3s-control
k3s-worker-1
k3s-worker-2
k3s-worker-3
```

Debe probar:

- El nuevo nodo se incorpora sin reinstalar el cluster.
- El alta se hace por inventario Ansible y re-ejecucion del playbook.
- The Store puede schedular pods en el nuevo nodo despues de importar imagenes y reiniciar deployments.

## 8. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigacion |
| --- | --- | --- |
| Docker build tarda o falla por red | La demo queda bloqueada | Construir imagenes antes y conservar tar exportado |
| Pods quedan `ImagePullBackOff` | The Store no despliega | Importar imagenes en todos los nodos K3s |
| Ingress no responde desde host | No se puede mostrar UI | Validar `ingress-nginx`, host header y `/etc/hosts` |
| Vagrant no levanta por recursos | Cluster incompleto | Definir RAM/CPU razonables y documentar requisitos minimos |
| Ansible no es idempotente | Re-ejecucion rompe entorno | Usar checks de existencia y handlers controlados |
| Worker nuevo no aparece | Falla caso de uso 3 | Separar playbook de join y validar token/API antes de unir |
| The Store funciona en Kind pero no en K3s | Diferencia de runtime/red | Validar temprano en K3s y no depender de `kind load` |

## 9. Criterios de finalizacion del POC

El POC se considera completo cuando se cumplen todos estos puntos:

- `vagrant up` crea las VMs iniciales.
- `ansible-playbook` instala y configura K3s.
- `kubectl get nodes` muestra 1 Control Plane y 2 Workers `Ready`.
- `kubectl get nodes` muestra `k3s-worker-3` `Ready` despues de fase 11.
- El cluster usa Pod CIDR `10.42.0.0/16` y Service CIDR `10.43.0.0/16`.
- The Store despliega sus 5 servicios en namespace `the-store`.
- Los pods quedan `Running` y los deployments `Available`.
- La UI es accesible por Ingress via HTTP.
- `scripts/validate-store.sh` valida el flujo funcional de The Store.
- Se puede agregar `worker-3` al inventario y re-ejecutar Ansible.
- `worker-3` aparece `Ready` sin reinstalar el cluster.
- Existe un `how-to` que reproduce todo el flujo.
- Existe un guion de presentacion y evidencia final de validacion.

## 10. Orden de trabajo recomendado

1. Crear `infra/Vagrantfile`.
2. Crear inventario Ansible.
3. Implementar rol `common`.
4. Implementar K3s server.
5. Implementar K3s workers.
6. Exportar kubeconfig al host.
7. Instalar Ingress.
8. Construir imagenes de The Store.
9. Importar imagenes a K3s.
10. Desplegar `dist/kubernetes.yaml`.
11. Validar acceso por Ingress.
12. Agregar worker nuevo.
13. Escribir `docs/how-to.md`.
14. Preparar guion de demo.

## 11. Decision clave

La arquitectura final no debe usar Kind para crear el cluster. Kind queda solo como referencia del repo original. La implementacion del TP debe mostrar el valor pedagogico aprobado: VMs reales, configuracion de sistema operativo, red privada, automatizacion con Ansible, bootstrap de K3s, union automatica de workers y gestion incremental del cluster.
