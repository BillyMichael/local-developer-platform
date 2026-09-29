# Workshops

These workshops teach platform engineering by building on LDP. Each one takes
an hour or two, builds on the one before, and leaves something running in your
cluster. Before you begin, run `make up` ([Getting Started](../getting-started/overview.md))
and check that `make status` shows all pods healthy.

The workshops follow one idea: a platform is a set of services people can get
for themselves. You install a tool, turn it into an API, make it a template,
then make it safe to operate.

| # | Workshop | You build | You learn |
|---|----------|-----------|-----------|
| 1 | [Add a platform Helm chart](01-platform-helm-chart.md) | Valkey (a Redis-compatible cache) running as a platform service | How a folder becomes a running app: ApplicationSets, sync waves, the catalog |
| 2 | [Turn it into an API with Crossplane](02-crossplane-composition.md) | A `Cache` kind that tenants request in one line | XRDs, compositions, composition functions, Crossplane RBAC, Argo CD health |
| 3 | Ship a golden path | A Backstage template that scaffolds an app with its own `Cache` | Scaffolder templates, tenant onboarding through Gitea and ApplicationSets |
| 4 | Give it single sign-on | Your app behind Authelia with one `Client` claim | OIDC, how the `oidc.ldp` composition wires Authelia and the consumer |
| 5 | Secrets that behave | Generated credentials that never rotate by accident | External Secrets generators, `CreatedOnce`, Reloader, why start-up order matters |
| 6 | Build and deploy from a commit | A push to Gitea that builds an image and rolls it out | Gitea Actions, the in-cluster registry, Argo CD image updates |
| 7 | Promote, don't just deploy | A dev → prod promotion for a tenant app | Kargo warehouses, stages and promotion tasks |
| 8 | Scale on demand | A worker that scales with its queue depth | KEDA scalers, metrics-server, requests and limits on a laptop |
| 9 | Break it, then fix it | A deliberately broken sync wave, diagnosed and repaired | Reading Argo CD status, the wave rollout, Reloader and probe failure modes |
| 10 | Keep it current | A Renovate chart bump reviewed and merged | Chart versioning, rendering a diff before you trust it, CI |

Workshops 1 and 2 are complete. Workshops 3 to 10 are outlines. The
platform's own charts are the worked examples for each.

## 3. Ship a golden path

Copy `spotify-templates/3-tier-app`, add a `Cache` from workshop 2 to its
chart, and register the template in Backstage's
`app-config.yaml`. Scaffold an app, push it to the `local-developer-platform`
organisation in Gitea with an `ldp.yaml` at its root, and watch the
`tenant-bootstrap` and `tenant-apps` ApplicationSets pick it up. The lesson is
the handover: the platform team owns the template and the composition, the
tenant owns the repo.

## 4. Give it single sign-on

Add a `Client` from the `oidc.ldp` group to your app's chart, as
`platform-apps/vcs/gitea/templates/oidc-client.yaml` does, and register the
client in Authelia's values. Read the composition in
`platform-apps/orchestration/crossplane-compositions/files/client.yaml.gotmpl`
to see the secret generated in `auth` and replicated to the consumer. The
lesson is that identity is a platform product too.

## 5. Secrets that behave

Follow the rules in
[Databases and generated secrets](../guides/adding-helm-charts.md#databases-and-generated-secrets)
against a deliberately naive chart: watch Reloader restart it when a secret
changes, watch a generator rotate a password on resync, then fix both. The
lesson is that most "flaky start-up" is ordering.

## 6. Build and deploy from a commit

Add a Gitea Actions workflow to your tenant app that builds its image and
pushes it to the in-cluster registry (`vcs-127-0-0-1.nip.io`), then let Argo
CD roll it out. `spotify-templates/3-tier-app` has a working example. The
lesson is what the platform must provide for CI to be trivial: a registry,
credentials, and trust.

## 7. Promote, don't just deploy

Kargo is installed and unused. Define a `Warehouse` watching your image and
two `Stage`s, dev and prod, in the tenant app's chart, and promote by hand,
then automatically. The lesson is separating "a build exists" from "a build
is running here".

## 8. Scale on demand

The agent template scales its worker on queue depth with a KEDA
`ScaledObject`. Do the same for the 3-tier backend on CPU, then on a custom
metric. The lesson is choosing a scaling signal that reflects user demand.

## 9. Break it, then fix it

Push a chart with a wrong image tag, a missing secret and a probe that can
never pass, one at a time. For each, find it from `make status`, Argo CD and
`kubectl describe`, and fix it with a commit. The lesson is the platform's
failure vocabulary: OutOfSync, Degraded, CrashLoopBackOff, and what each one
means about whose problem it is.

## 10. Keep it current

Renovate opens chart version bumps against this repo. Take one, render the
chart before and after (`helm template`), read the diff, run the CI checks
locally, and merge. The lesson is that upgrades are routine when the diff is
small and reviewed, and terrifying when it is neither.
