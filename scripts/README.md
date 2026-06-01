# Scripts del POC

Scripts de apoyo para ejecutar pasos repetibles de la demo.

Estos scripts no reemplazan a Ansible. Su objetivo es reducir errores operativos en tareas del host, como construir imagenes Docker o consultar estado.

## Scripts previstos

- `build-images.sh`: construye las imagenes locales de The Store.
- `export-images.sh`: exporta las imagenes a `/tmp/the-store-images.tar` para importarlas en K3s.
- `deploy-store.sh`: aplica los manifiestos de The Store, reinicia `checkout` si cambia su ConfigMap y espera pods listos.
- `status.sh`: muestra estado compacto del cluster, pods de sistema, Ingress y The Store con distribucion por nodo.
- `validate-store.sh`: ejecuta la validacion funcional de The Store contra el Ingress de K3s.

## Validacion funcional

Con el cluster K3s y The Store ya desplegados:

```bash
bash scripts/validate-store.sh
```

Por defecto valida `http://192.168.56.10` enviando `Host: localhost`, que coincide con el Ingress local del POC. Si se cambia el host o endpoint:

```bash
bash scripts/validate-store.sh --url http://192.168.56.10 --host localhost
```

## Estado de demo

`status.sh` usa `infra/kubeconfig` por defecto cuando existe. Si se necesita otro cluster, exportar `KUBECONFIG` antes de ejecutarlo:

```bash
bash scripts/status.sh
```

Esta salida es util para mostrar fase 11 porque incluye `kubectl get pods -o wide` y permite verificar si hay pods corriendo en `k3s-worker-3`.
