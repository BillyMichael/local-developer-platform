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

- **Resources:** at least 12GB memory and 4 CPUs
  (`LDP_SKIP_RESOURCE_CHECK=1` skips the check).
- **File sharing:** the checkout must be in a shared directory (home is
  shared by default).
- **Rootless Podman:** run
  `sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80` to allow ports 80
  and 443.
- **Corporate proxy:** if `make up` can't detect its CA, set
  `LDP_EXTRA_CA_FILE` to the CA's PEM file.

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
