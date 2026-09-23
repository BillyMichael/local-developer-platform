---
title: Local Developer Platform
template: home.html
hide:
  - navigation
  - toc
---

## What LDP installs

| Area | Components | What it does |
|------|------------|--------------|
| Networking | Traefik | Gives every tool its own web address on your machine |
| Certificates | cert-manager, trust-manager | Lets your browser open every tool securely |
| Secrets | External Secrets, Reloader, Replicator | Creates passwords and shares them with the tools that need them |
| Sign-in | LLDAP, Authelia | One username and password for every tool |
| Databases | CloudNativePG | Stores data for the tools that need it |
| Code | Gitea, Gitea Actions | Hosts your code and runs your builds |
| Deployment | ArgoCD, Crossplane, Kargo | Keeps the platform in line with the code that describes it |
| Portal | Backstage | One place to find and create services |
| AI agents | kagent | Runs AI assistants inside the platform |

## Where to next

<ul class="ldp-next" markdown>
<li markdown>[Getting started](getting-started/overview.md): prerequisites, `make up`, and the first login.</li>
<li markdown>[Adding a Helm chart](guides/adding-helm-charts.md): how a new folder becomes a running app.</li>
<li markdown>[Architecture](architecture/overview.md): how the components depend on each other.</li>
</ul>
