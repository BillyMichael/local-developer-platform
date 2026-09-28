# Workshop 1: Add a platform Helm chart

You will add **Valkey**, a Redis-compatible cache, as a platform service.
When you finish, it runs in the `storage` namespace, Argo CD manages it, and
it appears in Backstage's catalog. Workshop 2 turns it into something tenants
can request for themselves.

**Time:** about an hour. **Needs:** a running platform (`make status` shows
all pods healthy).

## How a folder becomes an app

The platform ApplicationSet in `platform-apps/orchestration/argocd` scans this
checkout for `platform-apps/<area>/<name>/values.yaml`. Every match becomes an
Argo CD Application: the chart is `platform-apps/<area>/<name>`, the namespace
is `<area>`, and `ldp.syncWave` in the values decides when it rolls out
relative to everything else. Argo CD reads the committed `HEAD` of your
checkout, so a commit is a deploy. There is no registry of apps to update.

## 1. Create the chart

```bash
mkdir -p platform-apps/storage/valkey
```

```yaml title="platform-apps/storage/valkey/Chart.yaml"
apiVersion: v2
name: valkey
version: 1.0.0
dependencies:
  - name: valkey
    version: 3.0.31
    repository: oci://registry-1.docker.io/bitnamicharts
```

This is a wrapper chart: it pins an upstream chart as a dependency and adds
the platform's own values and templates around it. Every platform app is built
this way, so Renovate can bump the version and you can add templates without
forking upstream.

## 2. Set the values

```yaml title="platform-apps/storage/valkey/values.yaml"
# Shared cache for platform services. Standalone: one primary, no replicas.
ldp:
  syncWave: wave-4

valkey:
  architecture: standalone
  auth:
    enabled: false
  primary:
    resources:
      requests:
        cpu: 25m
        memory: 64Mi
      limits:
        memory: 128Mi
    persistence:
      enabled: false
```

Two things to notice. `ldp.syncWave: wave-4` places it with the other
operators and stores, after cert-manager and before anything that might use
it. And every container gets a memory request and limit: on a laptop VM the
scheduler needs the numbers, and a runaway cache should not take Gitea with
it.

## 3. Put it in the catalog

```yaml title="platform-apps/storage/valkey/catalog-info.yaml"
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: valkey
  annotations:
    argocd/app-name: valkey
    backstage.io/kubernetes-namespace: storage
    backstage.io/kubernetes-label-selector: app.kubernetes.io/instance=valkey
  description: Shared Redis-compatible cache for platform services.
spec:
  type: infrastructure
  lifecycle: production
  owner: group:default/platform_maintainers
  system: developer_platform
```

Backstage reads every `platform-apps/**/catalog-info.yaml`. The annotations
link the entity to its Argo CD Application and its pods, which is what makes
the portal's Argo CD and Kubernetes tabs work.

## 4. Render it before you commit

```bash
helm dependency build platform-apps/storage/valkey
helm template valkey platform-apps/storage/valkey -n storage | less
```

Read what you are about to deploy. Check the StatefulSet's resources, that
`auth` is off, and that nothing asks for a PersistentVolumeClaim. This is the
habit the whole job rests on: never trust a chart you have not rendered.

## 5. Commit

```bash
git add platform-apps/storage/valkey
git commit -m "feat(storage): add valkey"
```

Nothing to push. Within ten seconds the ApplicationSet sees the new folder and
creates the Application; because wave 4 is already past, it syncs at once.

## 6. Verify

```bash
kubectl -n orchestration get application valkey
kubectl -n storage get pods -l app.kubernetes.io/instance=valkey
```

Then in the browser:

- Argo CD (`make info` for the address): the `valkey` Application is Synced
  and Healthy, and its resource tree shows the StatefulSet.
- Backstage: the `valkey` component is in the catalog with a Kubernetes tab
  showing its pod.

Finally, use it:

```bash
kubectl -n storage run redis-cli --rm -it --restart=Never \
  --image=docker.io/valkey/valkey:8 -- valkey-cli -h valkey-primary PING
```

`PONG` means you have a platform service.

## What you learned

- A platform app is a wrapper chart, values, and a catalog entry. The
  ApplicationSet does the rest.
- Sync waves express dependencies between platform apps; tenants never see
  them.
- Render before you commit, and commit to deploy.

## Stretch

- Make Valkey require a password: generate one with an External Secrets
  `Password` generator, following the [rules for generated
  secrets](../guides/adding-helm-charts.md#databases-and-generated-secrets).
- Give it a `ServiceMonitor` or `prometheus.io/scrape` annotations, ready for
  a metrics stack.

Next: [Workshop 2](02-crossplane-composition.md) turns this one shared cache
into a `Cache` API that gives every tenant their own.
