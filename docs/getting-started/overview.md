# Getting Started

This guide will help you set up and run the Local Developer Platform on your local machine.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Docker Engine** or **Podman** — [Install Docker](https://docs.docker.com/engine/install/) or [Install Podman](https://podman.io/docs/installation)
- **kind** — [Install kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- **kubectl** — [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
- **Helm** — [Install Helm](https://helm.sh/docs/intro/install/)
- **Make** — Usually pre-installed on macOS/Linux

!!! note
    Docker Desktop is **not supported**. Use Docker Engine (Linux) or Podman instead.

**System Requirements:**

- 12GB+ RAM available for the container runtime
- 4+ CPU cores recommended

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/BillyMichael/local-developer-platform.git
cd local-developer-platform
```

### 2. Check Prerequisites

```bash
make preflight
```

This verifies your container engine, required tools, port availability, and system resources.

### 3. Create the Platform

```bash
make up
```

This will:

- Create a KIND cluster with 1 control-plane and 2 worker nodes
- Install ArgoCD and bootstrap all platform applications via GitOps
- Configure CoreDNS for local service resolution
- Wait for authentication services to become ready
- Display credentials and service URLs

Takes approximately 5–10 minutes on first run.

### 4. Check Platform Health

```bash
make status
```

## Accessing Services

Once deployed, services are available at:

| Service   | URL                                  |
|-----------|--------------------------------------|
| ArgoCD    | https://cd-127-0-0-1.nip.io         |
| Authelia   | https://auth-127-0-0-1.nip.io       |
| Gitea     | https://vcs-127-0-0-1.nip.io        |
| Backstage | https://portal-127-0-0-1.nip.io     |

Credentials are displayed after `make up` completes, or run `make info` to see them again.

!!! warning
    You will see browser security warnings for self-signed certificates. This is expected in local development.

## Useful Commands

| Command          | Description              |
|------------------|--------------------------|
| `make up`        | Create the cluster       |
| `make down`      | Delete the cluster       |
| `make restart`   | Restart the cluster      |
| `make info`      | Show credentials & URLs  |
| `make status`    | Show platform health     |
| `make kubeconfig`| Update kubeconfig        |
| `make preflight` | Check prerequisites      |

## Next Steps

- [Adding a Helm Chart](../guides/adding-helm-charts.md) - Learn how to add new applications
- [Architecture Overview](../architecture/overview.md) - Understand the platform design
