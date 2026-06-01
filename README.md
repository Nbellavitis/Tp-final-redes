# The Store

[![Build](https://github.com/jupmoreno/the-store/actions/workflows/main.yml/badge.svg)](https://github.com/jupmoreno/the-store/actions/workflows/main.yml)

## Trabajo practico: K3s multi-nodo local

Este repo incluye la implementacion del POC de Redes para desplegar The Store sobre K3s con Vagrant + Ansible:

- Guia operativa: [docs/how-to.md](docs/how-to.md)
- Plan de ejecucion: [docs/plan-ejecucion-k3s-the-store.md](docs/plan-ejecucion-k3s-the-store.md)
- Guion de presentacion: [docs/guion-presentacion.md](docs/guion-presentacion.md)
- Validacion final: [docs/validacion-final.md](docs/validacion-final.md)
- Infraestructura: [infra/README.md](infra/README.md)

Resumen del POC:

- 1 Control Plane y 2 Workers iniciales.
- Worker adicional `k3s-worker-3` para demo de gestion basica.
- K3s `v1.35.5+k3s1`.
- Red host-only `192.168.56.0/24`.
- Ingress con `ingress-nginx`.
- The Store desplegada en namespace `the-store`.

**The Store** is a modern e-commerce platform built with microservices architecture.

Our platform provides a complete shopping experience with:
- **Beautiful storefront** with customizable themes and responsive design
- **Scalable microservices** built with multiple languages and frameworks
- **Real-time inventory management** and order processing

## 🏗️ Architecture

The Store is built with a microservices architecture that uses different technologies:

![Architecture](/docs/images/architecture.png)

| Service | Language | Description |
|---------|----------|-------------|
| [UI](./src/ui/) | Java (Spring Boot) | Modern web interface with themes and chat bot |
| [Catalog](./src/catalog/) | Go | Product catalog API with search and filtering |
| [Cart](./src/cart/) | Java (Spring Boot) | Shopping cart management with Redis/DynamoDB |
| [Orders](./src/orders/) | Java (Spring Boot) | Order processing and management |
| [Checkout](./src/checkout/) | Node.js (NestJS) | Checkout orchestration and payment processing |


## 🛠️ Development

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) running
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) installed
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed

### Cluster Management

Use the `local.sh` script to manage your local Kubernetes cluster:

```bash
# Create a new cluster and deploy all services
./local.sh create-cluster

# Rebuild the entire cluster (delete and recreate)
./local.sh rebuild-cluster

# Delete the cluster
./local.sh delete-cluster

# Check cluster status
./local.sh status

# Build and load Docker images only
./local.sh reload-images
```

After running `./local.sh create-cluster`, access The Store at: **http://localhost**.

### Testing

#### E2E Testing

Run end-to-end tests to validate the complete system:

```bash
# Run e2e tests on existing cluster
./local.sh e2e-test
```

**Note**: These tests are run automatically when creating or rebuilding the cluster. You can skip them using the `--skip-tests` parameter for faster setup:

```bash
# Create cluster without running tests (faster setup)
./local.sh create-cluster --skip-tests

# Rebuild cluster without running tests
./local.sh rebuild-cluster --skip-tests
```

#### Load Testing
Run load generator tests to validate system performance:

```bash
# Run load generator tests
./local.sh load-test
```

The load generator will run performance tests against your local cluster for 10 minutes (or until manually stopped) to validate system behavior under load.

---

**The Store** - Built with ❤️ for modern e-commerce
