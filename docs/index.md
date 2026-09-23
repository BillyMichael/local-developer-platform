---
title: Local Developer Platform
template: home.html
hide:
  - navigation
  - toc
---

## What LDP installs

| Layer | Components | What it does |
|-------|------------|--------------|
| Networking | Traefik | Ingress for `*.127-0-0-1.nip.io` |
| PKI | cert-manager, trust-manager | Local CA and TLS for every service |
| Secrets | External Secrets, Reloader, Replicator | Generate, sync, and roll out secrets |
| Auth | LLDAP, Authelia | Directory and single sign-on |
| Storage | CloudNativePG | PostgreSQL for the platform apps |
| VCS | Gitea, Gitea Actions | Git hosting and CI runners |
| Orchestration | ArgoCD, Crossplane, Kargo | GitOps, infrastructure, promotion |
| Portal | Backstage | Service catalog and scaffolder |
| Devtools | kagent | AI agent runtime |

## Where to next

<ul class="ldp-next" markdown>
<li markdown>[Getting started](getting-started/overview.md): prerequisites, `make up`, and the first login.</li>
<li markdown>[Adding a Helm chart](guides/adding-helm-charts.md): how a new folder becomes a running app.</li>
<li markdown>[Architecture](architecture/overview.md): how the components depend on each other.</li>
</ul>
