# Getting Started

## Prerequisites

- **Docker Engine**, **Docker Desktop**, or **Podman** — [Install Docker](https://docs.docker.com/engine/install/) or [Install Podman](https://podman.io/docs/installation)
- **kind** — [Install kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- **kubectl** — [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
- **Helm** — [Install Helm](https://helm.sh/docs/intro/install/)
- **Make** — usually pre-installed on macOS/Linux

The engine is detected automatically; Docker is preferred when both are
present. Set `KIND_EXPERIMENTAL_PROVIDER=podman` to force Podman.

## Engine setup

- **Memory.** Give the engine's VM 12GB+ (4+ CPUs). On a 16GB laptop leave
  the rest to the host: a 16GB VM makes macOS swap the VM itself. Docker
  Desktop: *Settings → Resources*. Podman:
  `podman machine stop && podman machine set --memory 12288 && podman machine start`.
  `make up` stops when memory is short; `LDP_SKIP_RESOURCE_CHECK=1` overrides that.
- **File sharing.** The platform is deployed from this checkout, mounted into
  the kind nodes (see [GitOps flow](../architecture/overview.md#gitops-flow)).
  Docker Desktop and Podman machine share your home directory by default; a
  checkout elsewhere needs adding to the engine's file sharing.
- **Rootless Podman.** Binding ports 80/443 needs
  `sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80`, or use rootful
  Podman (`sudo systemctl start podman.socket`,
  `export CONTAINER_HOST=unix:///run/podman/podman.sock`).
- **TLS-inspecting proxies.** Behind Netskope, Zscaler or similar, `make up`
  detects the re-signing CA on the path to github.com and trusts it on the
  nodes, in Argo CD, in Crossplane and in the platform trust bundle. If
  detection misses it, point `LDP_EXTRA_CA_FILE` at the CA's PEM file.

## Quick Start

```bash
git clone https://github.com/BillyMichael/local-developer-platform.git
cd local-developer-platform
make preflight   # engine, tools, ports, memory
make up
```

`make up` creates a two-node kind cluster, installs Argo CD, and rolls the
platform out in waves from the committed `HEAD` of this checkout. The first
run takes 20–30 minutes, almost all of it pulling images; `make status` shows
progress. When it finishes it prints every tool's address and the sign-in
credentials (`make info` shows them again).

The platform issues its own certificates, so browsers warn until you run
`make trust-ca` once.

## Commands

| Command           | Description                       |
|-------------------|-----------------------------------|
| `make up`         | Create the cluster                |
| `make down`       | Delete the cluster                |
| `make restart`    | Delete and recreate               |
| `make info`       | Show credentials and URLs         |
| `make status`     | Show platform health              |
| `make kubeconfig` | Update kubeconfig                 |
| `make preflight`  | Check prerequisites               |
| `make trust-ca`   | Trust the platform certificates   |

## Next Steps

- [Adding a Helm Chart](../guides/adding-helm-charts.md)
- [Architecture Overview](../architecture/overview.md)
