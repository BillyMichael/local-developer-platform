# Workshop 1: Add a platform Helm chart

Run `mkdir -p platform-apps/storage/valkey`. That's step 1 of 6.

You're adding **Valkey**, a Redis-compatible cache, as a platform service.
Six steps, about an hour. At the end it runs in the `storage` namespace, Argo
CD manages it, and Backstage lists it.

Before you start: `make status` shows all pods healthy.

## How a folder becomes an app

Argo CD looks for `platform-apps/<area>/<name>/values.yaml`. Each one becomes
an Application: the chart is that folder, the namespace is `<area>`, and
`ldp.syncWave` in the values says when it rolls out. Argo CD reads the
committed `HEAD` of your checkout, so a commit is a deploy.

## 1. Create the chart

Run:

```bash
mkdir -p platform-apps/storage/valkey
```

Then create this file:

```yaml title="platform-apps/storage/valkey/Chart.yaml"
apiVersion: v2
name: valkey
version: 1.0.0
dependencies:
  - name: valkey
    version: 3.0.31
    repository: oci://registry-1.docker.io/bitnamicharts
```

This is a wrapper chart. It pins the upstream chart as a dependency and adds
the platform's own values and templates around it. Every platform app works
this way, so Renovate can bump versions and you can add templates without
forking anything.

Step 1 of 6 done: the chart exists, with nothing configured yet.

## 2. Set the values

Create this file:

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

Two things to notice. `ldp.syncWave: wave-4` puts it with the other stores
and operators, after cert-manager and before anything that might use it. And
every container gets a memory request and limit. On a laptop the scheduler
needs the numbers, and a runaway cache shouldn't take Gitea down with it.

Step 2 of 6 done: the chart knows what to deploy.

## 3. Put it in the catalog

Create this file:

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
link the entry to its Argo CD Application and its pods, which is what makes
the Argo CD and Kubernetes tabs work.

Step 3 of 6 done: Backstage will find it.

## 4. Render it before you commit

Run:

```bash
helm dependency build platform-apps/storage/valkey
helm template valkey platform-apps/storage/valkey -n storage | less
```

Read what you're about to deploy. Check the StatefulSet's resources, that
auth is off, and that nothing asks for a PersistentVolumeClaim. Get into this
habit: never trust a chart you haven't rendered.

Step 4 of 6 done: you have read what you're about to deploy.

## 5. Commit

Run:

```bash
git add platform-apps/storage/valkey
git commit -m "feat(storage): add valkey"
```

No push needed. Within ten seconds the ApplicationSet sees the new folder and
creates the Application. Wave 4 has already passed, so it syncs straight away.

Step 5 of 6 done: Argo CD is deploying it.

## 6. Verify

Run:

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

`PONG` means it works. Step 6 of 6 done. Valkey is a platform service.

## What you learned

- A platform app is a wrapper chart, some values and a catalog entry.
- Sync waves order platform apps. Tenants never see them.
- Render before you commit. Commit to deploy.

## Stretch

Pick one:

- Make Valkey need a password. Generate one with an External Secrets
  `Password` generator, following the [rules for generated
  secrets](../guides/adding-helm-charts.md#databases-and-generated-secrets).
- Add `prometheus.io/scrape` annotations so a metrics stack could pick it up.

Next: open [Workshop 2](02-crossplane-composition.md).
