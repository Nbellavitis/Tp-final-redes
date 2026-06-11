# Guion de presentacion y demo

Guion breve para defender el POC de K3s multi-nodo para The Store.

## 1. Apertura

Objetivo del trabajo:

- Desplegar una aplicacion de microservicios en un cluster Kubernetes local.
- Automatizar infraestructura con Vagrant y configuracion con Ansible.
- Demostrar una operacion basica de gestion: agregar un worker sin reinstalar el cluster.

Contrato de arquitectura:

- 1 Control Plane inicial: `k3s-control`.
- 2 Workers iniciales: `k3s-worker-1`, `k3s-worker-2`.
- Worker adicional de demo: `k3s-worker-3`.
- Red privada `192.168.56.0/24`.
- K3s `v1.35.5+k3s1`.
- Flannel VXLAN por `eth1`.
- Traefik deshabilitado.
- Ingress con `ingress-nginx`.
- Persistencia y mensajeria `in-memory`, sin storage distribuido.

## 2. Infraestructura base

Mostrar:

```bash
(cd infra && vagrant status)
```

Mensaje para explicar:

- Vagrant define las VMs y sus IPs.
- Ansible configura SO, K3s, kubeconfig, Ingress, imagenes y deploy.
- La red host-only permite comunicacion estable entre nodos.

## 3. Cluster K3s

Mostrar:

```bash
kubectl --kubeconfig infra/kubeconfig get nodes -o wide
```

Puntos clave:

- Todos los nodos estan `Ready`.
- Las IPs internas son `192.168.56.10`, `192.168.56.11`, `192.168.56.12` y `192.168.56.13`.
- La version K3s esta pinneada para evitar drift entre nodos.

## 4. Aplicacion desplegada

Mostrar:

```bash
kubectl --kubeconfig infra/kubeconfig get pods -n the-store -o wide
kubectl --kubeconfig infra/kubeconfig get svc -n the-store
kubectl --kubeconfig infra/kubeconfig get ingress -n the-store -o wide
```

Puntos clave:

- The Store corre en namespace `the-store`.
- Los servicios son `ClusterIP`.
- El acceso externo entra por el Ingress `ui`.
- El host del Ingress es `localhost`, por eso se valida con header `Host: localhost`.

## 5. Validacion funcional

Mostrar:

```bash
bash scripts/validate-store.sh
```

Explicar que el script valida:

- Home.
- Topologia de servicios.
- Catalogo.
- Detalle de producto.
- Carrito.
- Checkout.
- Orden final.

Para una validacion manual rapida:

```bash
curl -H 'Host: localhost' http://192.168.56.10/
```

## 6. Escalado bajo carga: sube la demanda

Escalar `ui` para sumar capacidad. El servicio tiene anti-afinidad "una replica por nodo",
asi que con 3 nodos la 4a replica queda `Pending` (no hay donde ponerla):

```bash
kubectl --kubeconfig infra/kubeconfig -n the-store scale deployment/ui --replicas=4
kubectl --kubeconfig infra/kubeconfig -n the-store get pods -l app.kubernetes.io/name=ui -o wide
# 3 Running + 1 Pending; el evento dice "didn't match pod anti-affinity rules".
```

Punto clave: es **escalado manual** (`kubectl scale`), no autoscaling (declarado fuera de alcance).

## 7. Agregar worker-3 y que entre al balanceo

Sumar el nodo (sin reinstalar el Control Plane; token de join via Ansible; imagenes locales
importadas para evitar `ImagePullBackOff`):

```bash
(cd infra && vagrant up k3s-worker-3)
(cd infra/ansible && ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3)
(cd infra/ansible && ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3 -e import_store_images=true --tags images)
```

La replica `Pending` se programa sola en `k3s-worker-3` y entra al Service `ui`:

```bash
kubectl --kubeconfig infra/kubeconfig get nodes -o wide
kubectl --kubeconfig infra/kubeconfig -n the-store get pods -l app.kubernetes.io/name=ui -o wide
kubectl --kubeconfig infra/kubeconfig -n the-store get endpointslices -l kubernetes.io/service-name=ui -o wide
```

Puntos clave:

- `k3s-worker-3` queda `Ready` y la 4a replica de `ui` corre ahi.
- El pod de worker-3 aparece como endpoint READY del Service `ui`: queda en la rotacion de
  balanceo (recibe su parte del trafico). El nodo nuevo **participa del servicio**, no solo
  "queda disponible para scheduling".

Scale-in (cuando baja la carga, se retira el nodo: cierra el ciclo de elasticidad):

```bash
kubectl --kubeconfig infra/kubeconfig -n the-store scale deployment/ui --replicas=1
kubectl --kubeconfig infra/kubeconfig drain k3s-worker-3 --ignore-daemonsets --delete-emptydir-data
kubectl --kubeconfig infra/kubeconfig delete node k3s-worker-3
(cd infra && vagrant halt k3s-worker-3)
```

- Todo el ciclo (scale-out al sumar el nodo, scale-in al retirarlo) es **manual**, no autoscaling.

## 8. Limites del POC

Explicar explicitamente:

- No hay alta disponibilidad del Control Plane.
- No hay autoscaling.
- No hay storage distribuido.
- No hay cloud provider.
- No se expone el API Server por NAT para WSL.
- El objetivo es despliegue, automatizacion y gestion basica en entorno local.

## 9. Cierre

Resumen para cerrar:

- Infraestructura reproducible con Vagrant.
- Configuracion idempotente con Ansible.
- Cluster K3s multi-nodo operativo.
- The Store desplegada y validada funcionalmente.
- Worker adicional agregado sin recrear el cluster.
