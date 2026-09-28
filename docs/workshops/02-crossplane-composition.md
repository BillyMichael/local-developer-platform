# Workshop 2: Turn it into an API with Crossplane

Open `platform-apps/orchestration/crossplane-compositions` and skim the
`PostgresDatabase` files. That's the pattern you're copying.

You're building a `Cache` kind that a tenant can put in their own chart. Six
steps, one to two hours. Workshop 1 isn't needed.

Before you start: `make status` shows all pods healthy.

## How compositions work here

Crossplane v2 can create plain Kubernetes resources. A
**CompositeResourceDefinition** (XRD) declares a new kind and its schema. A
**Composition** says what to create for each one; here it hands the rendering
to `function-go-templating`, so the resources are a Go template in `files/`.
Crossplane can only create kinds it has RBAC for, and `rbac.yaml` grants that.
Argo CD uses the `Ready` condition of every `*.ldp` kind as its health, so a
`Cache` shows green or red like anything else.

## 1. Define the kind

Create this file:

```yaml title="platform-apps/orchestration/crossplane-compositions/templates/xrd-cache.yaml"
# Namespaced so a cache lives beside the app that uses it.
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: caches.storage.ldp
  annotations:
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
    argocd.argoproj.io/sync-wave: '-1'
spec:
  scope: Namespaced
  group: storage.ldp
  names:
    kind: Cache
    plural: caches
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      additionalPrinterColumns:
        - name: Memory
          type: string
          jsonPath: .spec.memory
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                memory:
                  type: string
                  description: Memory limit for the cache, also its maxmemory
                  default: 64Mi
                labels:
                  type: object
                  description: Labels copied onto the pod and service
                  additionalProperties:
                    type: string
```

The schema is the contract. Keep it small: every field you add is one you
support forever. With defaults, a tenant can write `kind: Cache` with an empty
spec and get something sensible.

Step 1 of 6 done: the API exists, with nothing behind it yet.

## 2. Write what an instance creates

Create this file:

```yaml title="platform-apps/orchestration/crossplane-compositions/files/cache.yaml.gotmpl"
{{- /* Rendered by function-go-templating, not Helm. */ -}}
{{- $xr := getCompositeResource . }}
{{- $name := $xr.metadata.name }}
{{- $ns := $xr.metadata.namespace }}
{{- $spec := $xr.spec }}
{{- $server := getComposedResource . "server" }}
{{- $ready := and $server (eq (int (dig "status" "readyReplicas" 0 $server)) 1) }}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ $name }}
  namespace: {{ $ns }}
  {{- with $spec.labels }}
  labels:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  annotations:
    gotemplating.fn.crossplane.io/composition-resource-name: server
    gotemplating.fn.crossplane.io/ready: {{ if $ready }}"True"{{ else }}"False"{{ end }}
spec:
  serviceName: {{ $name }}
  replicas: 1
  selector:
    matchLabels:
      storage.ldp/cache: {{ $name }}
  template:
    metadata:
      labels:
        storage.ldp/cache: {{ $name }}
        {{- with $spec.labels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      containers:
        - name: valkey
          image: docker.io/valkey/valkey:8-alpine
          args: ["--maxmemory", "{{ $spec.memory | lower | replace "i" "" }}b", "--maxmemory-policy", "allkeys-lru"]
          ports:
            - name: valkey
              containerPort: 6379
          readinessProbe:
            exec:
              command: ["valkey-cli", "PING"]
          resources:
            requests:
              cpu: 10m
              memory: {{ $spec.memory }}
            limits:
              memory: {{ $spec.memory }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}
  namespace: {{ $ns }}
  annotations:
    gotemplating.fn.crossplane.io/composition-resource-name: service
    # A Service has no Ready condition, so say so, or the Cache never goes Ready.
    gotemplating.fn.crossplane.io/ready: "True"
spec:
  selector:
    storage.ldp/cache: {{ $name }}
  ports:
    - name: valkey
      port: 6379
```

Three things matter here:

- `composition-resource-name` gives each resource a name so Crossplane can
  track it between runs, and `getComposedResource` lets the template read back
  what it created last time.
- The `ready` annotation tells Crossplane when each resource is ready, and
  every resource needs one. For the StatefulSet it's "one ready replica". For
  the Service it's just `"True"`, because a Service has no Ready condition.
  Miss one and the `Cache` says `Unready resources: service` forever, and any
  sync wave waiting on it waits forever too.
- Everything goes in the `Cache`'s own namespace. That's what a namespaced XRD
  is for.

Step 2 of 6 done: the template is written.

## 3. Wire the composition to the template

Create this file:

```yaml title="platform-apps/orchestration/crossplane-compositions/templates/composition-cache.yaml"
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: cache.storage.ldp
  annotations:
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
    argocd.argoproj.io/sync-wave: '-1'
spec:
  compositeTypeRef:
    apiVersion: storage.ldp/v1alpha1
    kind: Cache
  mode: Pipeline
  pipeline:
    - step: render
      functionRef:
        name: function-go-templating
      input:
        apiVersion: gotemplating.fn.crossplane.io/v1beta1
        kind: GoTemplate
        source: Inline
        inline:
          template: |
{{ .Files.Get "files/cache.yaml.gotmpl" | indent 12 }}
```

Helm pastes the file in; Crossplane's function renders it. That's two
template languages in one file, which is why the `.gotmpl` file starts with a
comment saying which one it's for.

Step 3 of 6 done: Crossplane knows how to build a `Cache`.

## 4. Let Crossplane create these kinds

Add to `platform-apps/orchestration/crossplane-compositions/templates/rbac.yaml`:

```yaml
---
# Grants the kinds the Cache composition creates.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: crossplane:compose-cache
  labels:
    rbac.crossplane.io/aggregate-to-crossplane: "true"
  annotations:
    argocd.argoproj.io/sync-wave: '-2'
rules:
  - apiGroups: ["apps"]
    resources: ["statefulsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

Skip this and the composition renders fine but nothing appears. The `Cache`
shows a "forbidden" error in its `Synced` condition. It's the most common
first mistake, so that's the first place to look.

Step 4 of 6 done: Crossplane is allowed to build one.

## 5. Commit and check the definition landed

Run:

```bash
helm lint platform-apps/orchestration/crossplane-compositions
git add platform-apps/orchestration/crossplane-compositions
git commit -m "feat(crossplane): Cache kind for tenant caches"
kubectl get xrd caches.storage.ldp
kubectl get composition cache.storage.ldp
```

The `crossplane-compositions` Application is in wave 2, so Argo CD syncs the
change as soon as it sees the commit.

Step 5 of 6 done: the API is live.

## 6. Use it from a tenant chart

Put this in any chart:

```yaml title="templates/cache.yaml"
apiVersion: storage.ldp/v1alpha1
kind: Cache
metadata:
  name: {{ .Release.Name }}-cache
  annotations:
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  memory: 32Mi
```

The app reaches it at `<release>-cache:6379`. Try it in the `3-tier-app`
template's chart, or directly:

```bash
kubectl create namespace demo
kubectl -n demo apply -f - <<'YAML'
apiVersion: storage.ldp/v1alpha1
kind: Cache
metadata:
  name: demo
YAML
kubectl -n demo get cache demo -w
```

You should see `READY True` within a minute. `kubectl -n demo describe cache demo`
lists what it created, and `kubectl -n demo get sts,svc` shows them as normal
Kubernetes objects, because that's what they are. Step 6 of 6 done. Tenants
can now ask for a `Cache`.

## What you learned

- An XRD is the API. A composition is the implementation. RBAC is permission
  to implement it.
- You define what "ready" means. Argo CD turns that into green and red.
- A namespaced XRD keeps a tenant's resources in their namespace.

## Stretch

Pick one:

- Add `spec.password: true`. Generate the password with an External Secrets
  `Password` generator (`refreshPolicy: CreatedOnce`) and publish a
  `<name>-cache` secret, the way `PostgresDatabase` publishes `<name>-app`.
  `client.yaml.gotmpl` shows the generator pattern.
- Write a second Composition for the same XRD that points at a shared Valkey
  instead of creating one, and pick it with a label. That's how one API gets a
  cheaper implementation without its users changing anything.

Next: open [Workshop 3](index.md#3-ship-a-golden-path).
