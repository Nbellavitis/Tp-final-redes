# Validacion final del POC

Fecha de cierre: 2026-06-01.

Este documento resume la evidencia esperada para dar por completo el POC de K3s multi-nodo para The Store.

## Alcance validado

- Vagrant + Ansible + K3s sobre VMs VirtualBox.
- 1 Control Plane: `k3s-control`.
- 2 Workers iniciales: `k3s-worker-1`, `k3s-worker-2`.
- Worker adicional de fase 11: `k3s-worker-3`.
- `k3s-worker-3` definido con `autostart: false` para conservar el arranque inicial de 3 VMs.
- Red host-only `192.168.56.0/24`.
- Pod CIDR `10.42.0.0/16`.
- Service CIDR `10.43.0.0/16`.
- K3s `v1.35.5+k3s1`.
- Flannel VXLAN por `eth1`.
- Traefik deshabilitado.
- Ingress con `ingress-nginx`.
- The Store en namespace `the-store`.

## Comandos de cierre

Validaciones estaticas:

```bash
/usr/bin/ruby -c infra/Vagrantfile
bash -n local.sh scripts/*.sh infra/ansible/scripts/prepare-wsl-keys.sh
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --syntax-check
ansible-playbook -i inventory/hosts-wsl.yml playbooks/site.yml --syntax-check
ansible-playbook -i inventory/hosts.yml playbooks/deploy-store.yml --syntax-check
ansible-playbook -i inventory/hosts.yml playbooks/add-worker.yml --syntax-check
kubectl --kubeconfig infra/kubeconfig apply --dry-run=client -n the-store -f dist/kubernetes.yaml
```

Validaciones de cluster:

```bash
vagrant status
kubectl --kubeconfig infra/kubeconfig get nodes -o wide
kubectl --kubeconfig infra/kubeconfig wait --for=condition=Ready nodes --all --timeout=180s
kubectl --kubeconfig infra/kubeconfig cluster-info
```

Validaciones de The Store:

```bash
kubectl --kubeconfig infra/kubeconfig get pods -n the-store -o wide
kubectl --kubeconfig infra/kubeconfig get svc -n the-store
kubectl --kubeconfig infra/kubeconfig get ingress -n the-store -o wide
curl -H 'Host: localhost' http://192.168.56.10/
bash scripts/validate-store.sh
```

Validacion de fase 11 (escalado bajo carga + alta de worker):

```bash
# Carga + escalado: con 3 nodos, la 4a replica de ui queda Pending (anti-afinidad por nodo)
kubectl --kubeconfig infra/kubeconfig apply -f dist/load-generator.yaml
kubectl --kubeconfig infra/kubeconfig -n the-store scale deployment/ui --replicas=4
# Alta del worker on-demand
ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/add-worker.yml -e add_worker_target=k3s-worker-3
ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/add-worker.yml -e add_worker_target=k3s-worker-3 -e import_store_images=true --tags images
# La replica Pending se programa en worker-3 y entra al balanceo del Service ui
kubectl --kubeconfig infra/kubeconfig -n the-store get pods -l app.kubernetes.io/name=ui -o wide
kubectl --kubeconfig infra/kubeconfig -n the-store get endpointslices -l kubernetes.io/service-name=ui -o wide
```

## Resultado observado

- Las cuatro VMs quedaron `running`.
- Los cuatro nodos quedaron `Ready`.
- `k3s-worker-3` quedo unido con IP `192.168.56.13`.
- Las imagenes locales `the-store-*` quedaron importadas en todos los nodos.
- Los deployments de The Store quedaron `Available`.
- Los pods de The Store quedaron `Running`.
- En la demo de escalado (fase 11): al escalar `ui` a 4 con 3 nodos, una replica quedo `Pending` por la anti-afinidad; al sumar `k3s-worker-3` esa replica se programo ahi, entro como endpoint READY del Service `ui` y el pod sirvio trafico real del load-generator (medido en `http.server.requests`).
- `scripts/validate-store.sh` completo home, topologia, catalogo, producto, carrito, checkout y orden final.
- La re-ejecucion de playbooks principales quedo idempotente con `changed=0` en las pasadas de cierre.

## Limites declarados

- No hay HA del Control Plane.
- No hay autoscaling.
- No hay storage distribuido.
- No hay cloud provider.
- El inventario WSL cubre Ansible/SSH por NAT; el kubeconfig requiere ruta a `192.168.56.0/24` o validacion desde el Control Plane.
