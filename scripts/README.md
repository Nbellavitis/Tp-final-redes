# Scripts del POC

Scripts de apoyo para ejecutar pasos repetibles de la demo.

Estos scripts no reemplazan a Ansible. Su objetivo es reducir errores operativos en tareas del host, como construir imagenes Docker o consultar estado.

## Scripts previstos

- `build-images.sh`: construye las imagenes locales de The Store.
- `export-images.sh`: exporta las imagenes a `/tmp/the-store-images.tar` para importarlas en K3s.
- `deploy-store.sh`: aplica los manifiestos de The Store.
- `status.sh`: muestra estado compacto del cluster y la aplicacion.
- `validate-store.sh`: ejecuta la validacion funcional de fase 10 contra el Ingress de K3s.

## Validacion funcional

Con el cluster K3s y The Store ya desplegados:

```bash
bash scripts/validate-store.sh
```

Por defecto valida `http://192.168.56.10` enviando `Host: localhost`, que coincide con el Ingress local del POC. Si se cambia el host o endpoint:

```bash
bash scripts/validate-store.sh --url http://192.168.56.10 --host localhost
```
