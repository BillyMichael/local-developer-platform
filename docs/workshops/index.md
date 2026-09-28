# Workshops

Open [Workshop 1](01-platform-helm-chart.md). About an hour.

Before that, one check: `make status` shows all pods healthy.

Each workshop is one to two hours and builds on the last. Install a tool, turn
it into an API, make it a template, make it safe to run.

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

Workshops 1 and 2 are written up. Workshops 3 to 10 are outlines. Each
starts with the first thing to open.

## 3. Ship a golden path

Start: copy `spotify-templates/3-tier-app`.

1. Add a `Cache` from workshop 2 to its chart.
2. Register the template in Backstage's `app-config.yaml`.
3. Scaffold an app and push it to the `local-developer-platform` organisation
   in Gitea, with `ldp.yaml` at the root.
4. Watch the `tenant-bootstrap` and `tenant-apps` ApplicationSets pick it up.

The point: the platform team owns the template, the tenant owns the repo.

## 4. Give it single sign-on

Start: open `platform-apps/vcs/gitea/templates/oidc-client.yaml`.

1. Add a `Client` like it to your app's chart.
2. Register the client in Authelia's values.
3. Read `crossplane-compositions/files/client.yaml.gotmpl` to see how the
   secret is made in `auth` and copied to your app.

The point: login is something the platform provides too.

## 5. Secrets that behave

Start: read [Databases and generated secrets](../guides/adding-helm-charts.md#databases-and-generated-secrets).

1. Write a chart that breaks each rule.
2. Watch Reloader restart it when a secret changes.
3. Watch a generated password change on resync.
4. Fix both.

The point: most "flaky start-up" is an ordering problem.

## 6. Build and deploy from a commit

Start: open the workflow in `spotify-templates/3-tier-app`.

1. Add a Gitea Actions workflow to your app that builds its image.
2. Push the image to the in-cluster registry, `vcs-127-0-0-1.nip.io`.
3. Let Argo CD roll it out.

The point: CI is easy when the platform gives you a registry, credentials and
trust.

## 7. Promote, don't just deploy

Start: `kubectl -n orchestration get pods -l app.kubernetes.io/name=kargo`.
Kargo is installed and unused.

1. Add a `Warehouse` that watches your image.
2. Add two `Stage`s, dev and prod.
3. Promote by hand, then automatically.

The point: "a build exists" and "a build is running here" are different
things.

## 8. Scale on demand

Start: open `spotify-templates/agent/langgraph/chart/templates/queue.yaml`. It
scales a worker on queue depth with a KEDA `ScaledObject`.

1. Do the same for the 3-tier backend on CPU.
2. Then on a custom metric.

The point: pick a signal that reflects what users are doing.

## 9. Break it, then fix it

Start: change your app's image tag to one that doesn't exist and commit.

1. Find it with `make status`, Argo CD and `kubectl describe`. Fix it.
2. Repeat with a missing secret.
3. Repeat with a probe that can never pass.

The point: OutOfSync, Degraded and CrashLoopBackOff each mean something
different, and point at different people.

## 10. Keep it current

Start: open the newest Renovate pull request on this repo.

1. Render the chart before and after with `helm template`.
2. Read the diff.
3. Run the CI checks locally, then merge.

The point: upgrades are routine when the diff is small and you have read it.

Next: open [Workshop 1](01-platform-helm-chart.md).
