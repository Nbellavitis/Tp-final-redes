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

## 6. Agregado de worker

Mostrar el flujo de fase 11:

```bash
(cd infra && vagrant up k3s-worker-3)
(cd infra/ansible && ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3)
(cd infra/ansible && ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml -e add_worker_target=k3s-worker-3 -e import_store_images=true --tags images)
```

Luego:

```bash
kubectl --kubeconfig infra/kubeconfig get nodes -o wide
```

Puntos clave:

- No se reinstala el Control Plane.
- El token de join se obtiene desde Ansible.
- `k3s-worker-3` queda `Ready`.
- Se importan imagenes locales en el nuevo nodo para evitar `ImagePullBackOff`.

## 7. Scheduling en worker-3

Mostrar:

```bash
kubectl --kubeconfig infra/kubeconfig rollout restart deployment -n the-store
kubectl --kubeconfig infra/kubeconfig rollout status deployment -n the-store --timeout=300s
kubectl --kubeconfig infra/kubeconfig get pods -n the-store -o wide
```

Puntos clave:

- No se promete autoscaling.
- La prueba solo demuestra que el nodo nuevo queda disponible para scheduling.
- En la validacion realizada, `carts` y `orders` quedaron corriendo en `k3s-worker-3`.

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
