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

## Roles

- `common`: prerequisitos del sistema operativo.
- `k3s_server`: instalacion del Control Plane.
- `k3s_agent`: union de Workers.
- `ingress`: Ingress Controller.
- `the_store_images`: distribucion/importacion de imagenes locales.
