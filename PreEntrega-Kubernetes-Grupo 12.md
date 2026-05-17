          Pre-entrega: Trabajo Práctico Especial – Redes de Información
               Tema asignado: 6. Despliegue y Gestión del Cluster de Kubernetes – Grupo 12

     Propuesta de POC: automatizar la provisión y gestión de un clúster K3s multi-nodo local para desplegar
     The Store de forma reproducible, auditable y demostrable.


1. Problemática y contexto
The Store está compuesta por microservicios, por lo que necesita un entorno de orquestación de contenedores que
sea reproducible, consistente y sencillo de reinstalar para pruebas y demostraciones.
El armado manual de un clúster de Kubernetes introduce errores en la configuración de red, apertura de puertos,
distribución del token de join y alta de nodos. Además, dificulta auditar cambios y repetir el despliegue en distintos
entornos.
Para el TP se requiere una solución local que permita demostrar no solo el despliegue inicial del clúster, sino
también una operación básica de gestión sobre una topología multi-nodo similar a un escenario real.

2. Diseño de la solución
   Infraestructura: Vagrant aprovisionará tres máquinas virtuales Ubuntu Server 24.04 LTS conectadas mediante
    una red privada 192.168.56.0/24.
   Automatización: Ansible instalará dependencias, configurará parámetros del sistema y firewall, desplegará K3s
    en el nodo Control Plane y unirá los Workers utilizando automáticamente el token generado por el clúster. Los
    playbooks serán idempotentes.
   Orquestación: se utilizará K3s en una topología de 1 Control Plane y 2 Workers. La red overlay entre nodos se
    apoyará en Flannel (VXLAN) y se habilitará un Ingress Controller para exponer The Store por HTTP/HTTPS.
   Criterio de validación: el POC se considerará correcto si el clúster queda accesible vía kubectl, los nodos
    aparecen en estado Ready, la aplicación despliega sus pods y es posible incorporar un nuevo Worker sin
    reinstalar el entorno.

3. Scope del POC y casos de uso
El POC abarcará la provisión de infraestructura, el bootstrap del clúster, el despliegue de The Store y una operación
básica de gestión/expansión del clúster.
 Caso de uso 1: Aprovisionamiento automatizado (“Zero to Kube”): Ejecución de un único flujo para crear las
    VMs y configurar el clúster. Resultado esperado: un Control Plane y dos Workers visibles en kubectl get nodes y
    en estado Ready.
 Caso de uso 2: Despliegue de la aplicación: Ejecución del script provisto por la cátedra para desplegar The Store
    sobre el clúster recién inicializado. Resultado esperado: pods en estado Running, servicios accesibles y
    exposición mediante Ingress.
 Caso de uso 3: Gestión básica y escalabilidad: Alta de un nuevo Worker agregándolo al inventario de Ansible y
    re-ejecutando el playbook. Resultado esperado: el nuevo nodo se incorpora al clúster y queda disponible para
    scheduling de pods.
Fuera de alcance: no se implementarán alta disponibilidad del Control Plane, autoscaling, upgrades entre versiones,
almacenamiento persistente distribuido ni despliegue en cloud pública.
4. Diagrama de arquitectura




                              Figura 1. Arquitectura lógica y de red propuesta para el POC.

Resumen técnico del diagrama.
      Elemento                         Detalle
      SO de nodos                      Ubuntu Server 24.04 LTS
      Red privada                      192.168.56.0/24
                                       Control Plane 192.168.56.10 · Worker 1 192.168.56.11 · Worker 2
      IPs
                                       192.168.56.12
      Redes internas K3s               Pod CIDR 10.42.0.0/16 · Service CIDR 10.43.0.0/16
                                       SSH TCP/22 · Kubernetes API TCP/6443 · Flannel VXLAN UDP/8472 · Ingress
      Protocolos y puertos
                                       TCP/80 y TCP/443

5. Alternativas consideradas
   Minikube: se descartó porque su uso típico privilegia escenarios de uno o pocos nodos y oculta parte de la
    complejidad de bootstrap y gestión que este trabajo busca demostrar.
   Kind: se consideró útil para pruebas rápidas, pero al ejecutar nodos como contenedores pierde fidelidad
    respecto de una instalación sobre VMs y reduce el valor demostrativo de Ansible sobre sistema operativo, red y
    puertos.
   kops o cloud providers: se descartaron para evitar dependencia de cuentas externas, conectividad y posibles
    costos durante la exposición final.
