# Getting Started

This guide will help you set up and run the Local Developer Platform on your local machine.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Docker Engine**, **Docker Desktop**, or **Podman** — [Install Docker](https://docs.docker.com/engine/install/) or [Install Podman](https://podman.io/docs/installation)
- **kind** — [Install kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- **kubectl** — [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
- **Helm** — [Install Helm](https://helm.sh/docs/intro/install/)
- **Make** — Usually pre-installed on macOS/Linux

!!! note
    All three runtimes are supported and detected automatically. Docker is
    preferred when both are available; set `KIND_EXPERIMENTAL_PROVIDER=podman`
    to force Podman.

!!! tip "Docker Desktop"
    Raise the VM allocation to 12GB+ under **Settings → Resources**. The host
    may have plenty of RAM while the VM does not.

!!! tip "Rootless Podman"
    Binding ports 80/443 needs the unprivileged port floor lowered:
    `sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80`. Alternatively use
    rootful Podman via `sudo systemctl start podman.socket` and
    `export CONTAINER_HOST=unix:///run/podman/podman.sock`.

!!! tip "TLS-inspecting proxies"
    On networks with a TLS-inspecting proxy (Netskope, Zscaler, ...) every
    HTTPS connection is re-signed by a private CA that only the host trusts.
    `make up` detects this on the path to github.com and trusts the CA on the
    kind nodes, in Argo CD, in Crossplane and in the platform trust bundle. If
    detection misses your proxy, point `LDP_EXTRA_CA_FILE` at its PEM file.

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

When `make up` finishes, it prints the web address of every tool and the
usernames and passwords to sign in with. Run `make info` at any time to see
them again.

!!! tip "Browser security warnings"
    The platform uses its own certificates, so your browser will warn you the
    first time you open a tool. Run `make trust-ca` once to trust them and the
    warnings go away.

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
| `make trust-ca`  | Trust the platform certificates |

## Next Steps

- [Adding a Helm Chart](../guides/adding-helm-charts.md) - Learn how to add new applications
- [Architecture Overview](../architecture/overview.md) - Understand the platform design
