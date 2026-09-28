# Workshop 2: Turn it into an API with Crossplane

This workshop shows how to create a new kind of resource, `Cache`, that a
tenant can request in their own chart. Crossplane turns each `Cache` into a
Valkey StatefulSet and a Service.

## Before you begin

- A running platform. `make status` shows all pods healthy.
- Workshop 1 is not required.
- Read `platform-apps/orchestration/crossplane-compositions`. The
  `PostgresDatabase` kind there follows the same pattern.

This workshop takes one to two hours.

## Objectives

- Define a `Cache` kind with a CompositeResourceDefinition.
- Implement it with a Composition rendered by `function-go-templating`.
- Grant Crossplane permission to create the composed resources.
- Request a `Cache` and verify it becomes Ready.

## How compositions work in LDP

Crossplane creates ordinary Kubernetes resources. A CompositeResourceDefinition
(XRD) declares a new kind and its schema. A Composition says what to create
for each instance; in LDP it delegates rendering to `function-go-templating`,
so the resources are a Go template in `files/`. Crossplane can only create
kinds it has RBAC for, which `rbac.yaml` grants. Argo CD treats the `Ready`
condition of every `*.ldp` kind as its health, so a `Cache` shows as Healthy or
Progressing like any other resource.

## Define the kind

Create the XRD:

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

The schema is the API contract. Keep it small: every field you expose is one
you support from now on. The defaults let a tenant write `kind: Cache` with an
empty spec.

## Write the template

Create the Go template that renders each `Cache`:

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

Notice three things:

- `composition-resource-name` names each composed resource so Crossplane can
  track it between reconciles, and `getComposedResource` reads back what was
  created last time.
- The `ready` annotation tells Crossplane when each resource is ready. Every
  composed resource needs one. The StatefulSet is ready when it has one ready
  replica. A Service has no Ready condition, so its annotation is simply
  `"True"`. Without it, the `Cache` reports `Unready resources: service`
  forever.
- Everything is created in the `Cache`'s own namespace, because the XRD is
  namespaced.

## Configure the composition

Create the Composition. It inlines the template file:

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

Helm inlines the file; Crossplane's function renders it. The `.gotmpl` file
starts with a comment saying which of the two template languages it is for.

## Grant permission

Add this ClusterRole to
`platform-apps/orchestration/crossplane-compositions/templates/rbac.yaml`:

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

Without it the composition renders but nothing is created, and the `Cache`
shows a `forbidden` error in its `Synced` condition.

## Deploy the definition

1. Lint and commit:

    ```bash
    helm lint platform-apps/orchestration/crossplane-compositions
    git add platform-apps/orchestration/crossplane-compositions
    git commit -m "feat(crossplane): Cache kind for tenant caches"
    ```

    The `crossplane-compositions` Application is in wave 2, so Argo CD syncs
    it as soon as it sees the commit.

2. Check that the definition is established:

    ```bash
    kubectl get xrd caches.storage.ldp
    ```

    The output is similar to:

    ```
    NAME                 ESTABLISHED   OFFERED   AGE
    caches.storage.ldp   True                    30s
    ```

## Request a Cache

1. Create a namespace and a `Cache`:

    ```bash
    kubectl create namespace demo
    kubectl -n demo apply -f - <<'YAML'
    apiVersion: storage.ldp/v1alpha1
    kind: Cache
    metadata:
      name: demo
    YAML
    ```

2. Watch it become Ready:

    ```bash
    kubectl -n demo get cache demo -w
    ```

    The output is similar to:

    ```
    NAME   SYNCED   READY   MEMORY   AGE
    demo   True     False   64Mi     5s
    demo   True     True    64Mi     41s
    ```

3. Look at what was created:

    ```bash
    kubectl -n demo get sts,svc,pod
    ```

    The output is similar to:

    ```
    NAME                    READY   AGE
    statefulset.apps/demo   1/1     45s

    NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
    service/demo   ClusterIP   10.96.156.141   <none>        6379/TCP   45s

    NAME         READY   STATUS    RESTARTS   AGE
    pod/demo-0   1/1     Running   0          45s
    ```

4. Connect to it:

    ```bash
    kubectl -n demo run cli --rm -it --restart=Never \
      --image=docker.io/valkey/valkey:8-alpine -- valkey-cli -h demo PING
    ```

    The output is `PONG`.

In a tenant chart, the same request looks like this, and the app reaches the
cache at `<release>-cache:6379`:

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

## Clean up

Delete the `Cache` and the namespace. Crossplane removes the StatefulSet and
Service:

```bash
kubectl -n demo delete cache demo
kubectl delete namespace demo
```

Keep the XRD and Composition if you are continuing to Workshop 3.

## What's next

- [Workshop 3: Ship a golden path](index.md#3-ship-a-golden-path) puts a
  `Cache` in a Backstage template so tenants get one without writing YAML.
- To add a generated password, see how `client.yaml.gotmpl` uses an External
  Secrets `Password` generator, and the
  [rules for generated secrets](../guides/adding-helm-charts.md#databases-and-generated-secrets).
