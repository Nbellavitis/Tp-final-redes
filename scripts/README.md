# Scripts del POC

Scripts de apoyo para ejecutar pasos repetibles de la demo.

Estos scripts no reemplazan a Ansible. Su objetivo es reducir errores operativos en tareas del host, como construir imagenes Docker o consultar estado.

## Scripts previstos

- `build-images.sh`: construye las imagenes locales de The Store.
- `export-images.sh`: exporta las imagenes para importarlas en K3s.
- `deploy-store.sh`: aplica los manifiestos de The Store.
- `status.sh`: muestra estado compacto del cluster y la aplicacion.
