# Workshop 1: Add a platform Helm chart

This workshop shows how to add a new platform service to LDP. You add
Valkey, a Redis-compatible cache, as a Helm chart and watch Argo CD deploy
it.

## Before you begin

- A running platform. `make status` shows all pods healthy.
- The platform's checkout open in an editor.

This workshop takes about an hour.

## Objectives

- Create a wrapper chart for an upstream Helm chart.
- Place the chart in a sync wave and give it resource limits.
- Register the service in the Backstage catalog.
- Deploy it with a commit and verify it in Argo CD, Backstage and `kubectl`.

## How platform apps are discovered

Argo CD scans the checkout for `platform-apps/<area>/<name>/values.yaml`.
Each match becomes an Argo CD Application. The chart is that directory, the
namespace is `<area>`, and `ldp.syncWave` in the values decides when it rolls
out. Argo CD reads the committed `HEAD` of your checkout, so committing is
deploying.

## Create the chart

1. Create the chart directory:

    ```bash
    mkdir -p platform-apps/storage/valkey
    ```

2. Create `Chart.yaml`. It pins the upstream Valkey chart as a dependency:

    ```yaml title="platform-apps/storage/valkey/Chart.yaml"
    apiVersion: v2
    name: valkey
    version: 1.0.0
    dependencies:
      - name: valkey
        version: 3.0.31
        repository: oci://registry-1.docker.io/bitnamicharts
    ```

    Every platform app is a wrapper chart like this. Renovate can bump the
    version, and you can add templates without forking the upstream chart.

## Configure the values

Create `values.yaml`:

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

Notice two things. `ldp.syncWave: wave-4` places Valkey with the other
stores and operators, after cert-manager and before anything that might use
it. Every container also has a memory request and limit, so the scheduler can
place it on a laptop VM and a runaway cache cannot take other services down.

## Register it in the catalog

Create `catalog-info.yaml`:

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
link the entry to its Argo CD Application and its pods.

## Render the chart

Before committing, render the chart and read what you are about to deploy:

```bash
helm dependency build platform-apps/storage/valkey
helm template valkey platform-apps/storage/valkey -n storage
```

Check that the StatefulSet has the resources you set, that no
`PersistentVolumeClaim` is created, and that authentication is disabled.

## Deploy it

Commit the chart:

```bash
git add platform-apps/storage/valkey
git commit -m "feat(storage): add valkey"
```

There is nothing to push. Within about ten seconds Argo CD creates the
Application and, because wave 4 has already passed, syncs it immediately.

## Verify

1. Check the Application:

    ```bash
    kubectl -n orchestration get application valkey
    ```

    The output is similar to:

    ```
    NAME     SYNC STATUS   HEALTH STATUS
    valkey   Synced        Healthy
    ```

2. Check the pod:

    ```bash
    kubectl -n storage get pods -l app.kubernetes.io/instance=valkey
    ```

    The output is similar to:

    ```
    NAME               READY   STATUS    RESTARTS   AGE
    valkey-primary-0   1/1     Running   0          45s
    ```

3. Connect to it:

    ```bash
    kubectl -n storage run redis-cli --rm -it --restart=Never \
      --image=docker.io/valkey/valkey:8 -- valkey-cli -h valkey-primary PING
    ```

    The output is `PONG`.

4. Open Argo CD and Backstage (`make info` shows the addresses). Argo CD
   shows the `valkey` Application as Synced and Healthy. Backstage lists
   `valkey` in the catalog with a Kubernetes tab showing its pod.

## Clean up

To remove Valkey, delete the directory and commit. Argo CD prunes everything
it created:

```bash
git rm -r platform-apps/storage/valkey
git commit -m "chore(storage): remove valkey"
```

Keep it if you are continuing to Workshop 2.

## What's next

- [Workshop 2: Turn it into an API with Crossplane](02-crossplane-composition.md)
  gives every tenant their own cache from a one-line request.
- [Adding a Helm Chart](../guides/adding-helm-charts.md) covers the chart
  conventions in full, including
  [generated secrets](../guides/adding-helm-charts.md#databases-and-generated-secrets)
  if you want Valkey to require a password.
