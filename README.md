# Local Developer Platform (LDP)

This repository provides a reproducible **Internal Developer Platform** running entirely on a lightweight Kubernetes cluster (KIND). 

## What This Repository Provides

- A complete, local-first platform environment for demos and experimentation.
- GitOps  using **ArgoCD**.
- Core developer platform components:
  - Traefik (Ingress Controller)
  - Authelia (OIDC & SSO)
  - LLDAP (Directory Service)
  - Gitea (Git Server)
  - Backstage Developer Portal

## Prerequisites

Before you begin, ensure you have the following installed:

- **Docker** or **Podman** - [Install Docker](https://docs.docker.com/get-docker/) or [Install Podman](https://podman.io/docs/installation) 
- **kind** - [Install kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- **kubectl** - [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
- **Helm** - [Install Helm](https://helm.sh/docs/intro/install/)
- **Make** - Usually pre-installed on macOS/Linux

**System Requirements:**
- 12GB+ RAM available for Docker

## Getting Started

### 1. Clone the repository

```sh
git clone https://github.com/your-org/local-developer-platform.git
cd local-developer-platform
```

### 2. Create a local cluster

```sh
make up
```

This command will:
- Create a KIND cluster with appropriate port mappings
- Install ArgoCD
- Bootstrap all platform applications via GitOps
- Takes approximately 5-10 minutes on first run

## Accessing Services

After setup completes, details on how to access services will be provided via the CLI.

```==> Local Development Platform Info

User Credentials:

  ┌─────────────┬──────────────────────┬──────────────────────┐
  │ Role        │ Username             │ Password             │
  ├─────────────┼──────────────────────┼──────────────────────┤
  │ Maintainer  │ platform_maintainer  │ xxxxxxxx             │
  │ User        │ platform_user        │ xxxxxxxx             │
  └─────────────┴──────────────────────┴──────────────────────┘

URLs:

  ┌──────────────┬────────────────────────────────────────────┐
  │ Service      │ URL                                        │
  ├──────────────┼────────────────────────────────────────────┤
  │ ArgoCD       │ https://cd-127-0-0-1.nip.io                │
  │ Authelia     │ https://auth-127-0-0-1.nip.io              │
  │ Gitea        │ https://vcs-127-0-0-1.nip.io               │
  │ Backstage    │ https://portal-127-0-0-1.nip.io            │
  └──────────────┴────────────────────────────────────────────┘
```

**Note:** You may see browser security warnings for self-signed certificates. This is expected in local development.

## Repository Structure

```
local-developer-platform/
├── cluster/                   # Cluster creation & bootstrap scripts
├── platform-apps/             # All GitOps-managed applications
│   ├── auth/                  # Authelia, LLDAP
│   ├── networking/            # Traefik (Ingress Controller)
│   ├── pki/                   # Cert-Manager, Trust-Manager
│   ├── secrets/               # External-Secrets, Reloader, Replicator
│   ├── orchestration/         # ArgoCD, Crossplane, Kargo
│   ├── storage/               # CloudNativePG, MinIO
│   ├── vcs/                   # Gitea (Git server)
│   ├── portal/                # Backstage developer portal
│   └── devtools/              # Critiquely
├── spotify-backstage/         # Local Backstage app source
├── spotify-templates/         # Backstage scaffolder templates
├── docs/                      # MkDocs documentation
├── Makefile                   # LDP lifecycle commands
└── README.md
```

## Useful Commands

- **Create cluster:**  
  `make up`

- **Delete cluster:**  
  `make down`

- **Check prerequisites before creating cluster:**  
  `make preflight`

- **Show platform health status:**  
  `make status`

- **Update KubeConfig for the kind cluster:**  
  `make kubeconfig`

- **Provide info about the cluster such as usernames and ingresses:**  
  `make info`

## Contributing

Contributions are welcome! This platform is designed for clarity, reproducibility, and experimentation.

To contribute:
1. Fork the repository
2. Create a feature branch
3. Test your changes with `make up` on a fresh cluster
4. Submit a pull request with a clear description

## License

MIT

## Troubleshooting

WIP