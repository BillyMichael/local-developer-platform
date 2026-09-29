# Local Developer Platform (LDP)

A reproducible internal developer platform on a local [kind](https://kind.sigs.k8s.io/)
cluster: Traefik, cert-manager, External Secrets, Authelia and LLDAP for
sign-in, Gitea with Actions, CloudNativePG, ArgoCD, Crossplane, Kargo, KEDA,
Backstage, kagent, and VictoriaMetrics, VictoriaLogs and Perses for metrics,
logs and dashboards, all deployed by ArgoCD from this checkout.

Full documentation: [ldp.billymichael.uk](https://ldp.billymichael.uk/).

## Prerequisites

- Docker Engine, Docker Desktop or Podman; kind; kubectl; Helm; Make
- 12GB+ RAM and 4+ CPUs available to the container engine's VM
  (`make up` stops if memory is short)

## Getting Started

```sh
git clone https://github.com/BillyMichael/local-developer-platform.git
cd local-developer-platform
make up
```

`make up` creates the cluster, installs ArgoCD and rolls the platform out in
waves from the committed `HEAD` of this checkout, so a `git commit` is all it
takes to deploy a change. The first run takes 20–30 minutes, mostly image
pulls. It ends by printing every tool's address and the sign-in credentials;
`make info` shows them again, and `make trust-ca` removes the browser
certificate warnings.

| Command          | Description                     |
|------------------|---------------------------------|
| `make up`        | Create the cluster              |
| `make down`      | Delete the cluster              |
| `make preflight` | Check prerequisites             |
| `make status`    | Show platform health            |
| `make info`      | Show credentials and URLs       |
| `make kubeconfig`| Update kubeconfig               |
| `make trust-ca`  | Trust the platform certificates |

## Repository Structure

```
cluster/              # Cluster creation and bootstrap scripts
platform-apps/        # One Helm chart per platform app, grouped by namespace
spotify-backstage/    # The Backstage app
spotify-templates/    # Backstage scaffolder templates
docs/                 # MkDocs documentation
```

## Contributing

Fork, branch, test with `make up` on a fresh cluster, open a pull request.

## License

MIT
