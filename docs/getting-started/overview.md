# Getting Started

This guide will help you set up and run the Local Developer Platform on your local machine.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Docker Desktop** (or equivalent container runtime)
- **Kubernetes cluster** (kind, minikube, or Docker Desktop Kubernetes)
- **kubectl** - Kubernetes CLI
- **Helm** - Kubernetes package manager
- **Git** - Version control

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/BillyMichael/local-developer-platform.git
cd local-developer-platform
```

### 2. Create Kubernetes Cluster

If using kind:

```bash
kind create cluster --name ldp
```

### 3. Install ArgoCD

```bash
kubectl create namespace orchestration
kubectl apply -n orchestration -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 4. Deploy Platform Apps

```bash
kubectl apply -f platform-apps/orchestration/argocd/
```

ArgoCD will automatically discover and deploy all platform applications.

## Accessing Services

Once deployed, services are available at:

| Service | URL |
|---------|-----|
| ArgoCD | https://argocd.127-0-0-1.nip.io |
| Gitea | https://vcs.127-0-0-1.nip.io |
| Backstage | https://portal.127-0-0-1.nip.io |
| Authelia | https://auth.127-0-0-1.nip.io |

## Next Steps

- [Adding a Helm Chart](../guides/adding-helm-charts.md) - Learn how to add new applications
- [Architecture Overview](../architecture/overview.md) - Understand the platform design
