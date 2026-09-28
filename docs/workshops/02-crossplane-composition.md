# Workshop 2: Turn it into an API with Crossplane

A shared Valkey is a tool. A `Cache` kind that a tenant can put in their chart
is a platform product. You will define that kind with a Crossplane
CompositeResourceDefinition, implement it with a Composition that renders a
StatefulSet and a Service, and use it from a tenant chart.

**Time:** one to two hours. **Needs:** Workshop 1 is not required; this
composition stands alone. Read `platform-apps/orchestration/crossplane-compositions`
first: the `PostgresDatabase` kind there is the pattern you are copying.

## How compositions work here

Crossplane v2 composes ordinary Kubernetes resources, no cloud provider
needed. A **CompositeResourceDefinition** (XRD) declares a new kind and its
schema. A **Composition** says what to create for each instance, and here it
delegates the rendering to `function-go-templating`, so the resources are a
Go template in `files/`. Crossplane only creates kinds it has RBAC for, which
`rbac.yaml` grants. The platform's Argo CD already treats every `*.ldp` kind's
`Ready` condition as its health, so a claim shows up green or red like any
other resource.

## 1. Define the kind

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

The schema is the contract. Keep it small: every field you expose is one you
support forever. Defaults mean a tenant can write `kind: Cache` with an empty
spec and get something sensible.

## 2. Write what an instance creates

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

Three things carry the whole design:

- `composition-resource-name` names each composed resource so Crossplane can
  track it across reconciles, and `getComposedResource` lets the template read
  back what it created last time.
- The `ready` annotation is how the composite learns it is Ready, and every
  composed resource needs a verdict. The StatefulSet's is "one ready replica";
  the Service's is simply `"True"`, because a Service has no Ready condition
  of its own. Miss one and the `Cache` reports `Unready resources: service`
  forever, and so does any Argo CD sync wave waiting on it.
- Everything lands in the XR's own namespace, which is what a namespaced XRD
  is for.

## 3. Wire the composition to the template

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

Helm inlines the file; Crossplane's function renders it. Two template
languages in one file is why the `.gotmpl` file starts with a comment saying
which one it is for.

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

Skip this and the composition renders fine but nothing appears; the composite
reports a forbidden error in its `Synced` condition. It is the most common
first failure, so look for it there.

## 5. Commit and check the definition landed

```bash
helm lint platform-apps/orchestration/crossplane-compositions
git add platform-apps/orchestration/crossplane-compositions
git commit -m "feat(crossplane): Cache kind for tenant caches"
kubectl get xrd caches.storage.ldp
kubectl get composition cache.storage.ldp
```

The `crossplane-compositions` Application is in wave 2, so Argo CD syncs the
change as soon as it sees the commit.

## 6. Use it from a tenant chart

In any chart, this is now enough:

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

`READY True` within a minute. `kubectl -n demo describe cache demo` shows the
composed resources; `kubectl -n demo get sts,svc` shows them as plain
Kubernetes objects, because that is what they are.

## What you learned

- An XRD is an API contract; a composition is its implementation; RBAC is the
  permission to implement it. All three are just YAML in one chart.
- Readiness is something you define. The platform's Argo CD health check
  turns it into green and red for everyone.
- Namespaced composites keep a tenant's resources in the tenant's namespace,
  with no claims and no cross-namespace plumbing.

## Stretch

- Add `spec.password: true` that generates a password with an External
  Secrets `Password` generator (`refreshPolicy: CreatedOnce`) and publishes a
  `<name>-cache` connection secret, the way `PostgresDatabase` publishes
  `<name>-app`. The `client.yaml.gotmpl` composition shows the generator
  pattern.
- Write a second Composition for the same XRD that points at a shared Valkey
  instead of creating one, and select it with a label. That is how one API
  grows a cheaper implementation without changing its consumers.

Next: [Workshop 3](index.md#3-ship-a-golden-path) puts a `Cache` into a
Backstage template so tenants get one without writing YAML at all.
