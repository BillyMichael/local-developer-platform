# Local Developer Platform — Improvement Backlog

## Critical — Will Break or Already Broken

- [x] Docs workflow cache key references non-existent `requirements-docs.txt` — `.github/workflows/docs.yml`
- [x] Service URL mismatch between docs (`argocd.127-0-0-1.nip.io`) and reality (`cd-127-0-0-1.nip.io`) — `docs/getting-started/overview.md`
- [x] Broken "Next Steps" links point to `#` — `docs/guides/adding-helm-charts.md:393-394`
- [x] Crossplane-compositions chart deploys nothing (no deps, empty values, no templates) — `platform-apps/orchestration/crossplane-compositions/`
- [x] Kargo repo-secret template fully commented out, can't auth to git — `platform-apps/orchestration/kargo/templates/repo-secret.yaml`
- [x] Kargo `admin.yaml` is empty + `adminAccount.enabled: false`, no admin access path — `platform-apps/orchestration/kargo/templates/admin.yaml`
- [x] Kargo RoleBinding references `kargo-controller-read-secrets` ClusterRole that doesn't exist — `platform-apps/orchestration/kargo/templates/rbac.yaml:10-12`
- [x] MinIO `values.yaml` is empty, deployed with unknown defaults — `platform-apps/storage/minio/values.yaml`
- [x] ApplicationSet generator uses `revision: HEAD` but template uses `targetRevision: main` — `platform-apps/orchestration/argocd/templates/applicationsets-platform.yaml:11`

## High — Security or Reliability

- [x] Backstage `dangerouslyDisableDefaultAuthPolicy: true` — `platform-apps/portal/backstage/templates/app-config.yaml:20`
- [x] `latest` image tags in authelia init container, lldap bootstrap, gitea bootstrap, backstage — pin to specific versions
- [x] Weak authelia service account password generator (8 chars, lowercase only) — `platform-apps/auth/lldap-chart/templates/user-authelia.yaml:9-12`
- [x] Backstage uses allow-all permission policy — `spotify-backstage/packages/backend/src/index.ts:98`
- [ ] Hardcoded default credentials in scaffolder template (`password`, `minioadmin`) — `spotify-templates/3-tier-app/content/backend/index.js:13,22-23`
- [x] No `set -euo pipefail` in Authelia init container sed pipeline — `platform-apps/auth/authelia/values.yaml:209-255`
- [ ] Backstage CI builds but never runs tests — `.github/workflows/backstage.yaml`
- [ ] CA certificate has no explicit duration/renewBefore, defaults to 90 days — `platform-apps/pki/cert-manager/templates/selfsigned-issuer.yaml:9-21`

## Medium — Consistency, Config Quality, DX

- [x] Authelia trace logging and client debug messages enabled — `platform-apps/auth/authelia/values.yaml:14,92`
- [ ] Kargo cluster-promotion-tasks use Akuity example values, not real config — `platform-apps/orchestration/kargo/templates/cluster-promotion-tasks.yaml:8,12`
- [ ] Gitea bootstrap job has no empty POD_NAME guard — `platform-apps/vcs/gitea/templates/job-bootstrap.yaml:72`
- [ ] GitHub Actions pinned to major version only, not exact — both workflow files
- [ ] pip packages not pinned in docs workflow — `.github/workflows/docs.yml:44-45`
- [ ] Backstage catalog references external GitHub, not local Gitea — `platform-apps/portal/backstage/templates/app-config.yaml:53-55`
- [ ] 3-tier-app template uses node:18-alpine (EOL) — `spotify-templates/3-tier-app/content/infra/backend.yaml:17`
- [ ] Frontend template variable syntax (`${{ values.component_id }}`) won't work in JSX — `spotify-templates/3-tier-app/content/frontend/src/App.jsx:9`
- [ ] No error handling in template frontend fetch chain — `spotify-templates/3-tier-app/content/frontend/src/App.jsx:8-14`
- [ ] Backend template leaks error details to client — `spotify-templates/3-tier-app/content/backend/index.js:34-35`

## Low — Nice to Have

- [x] Missing `CODEOWNERS` file — `.github/`
- [x] `useDefaultCAs: false` is a no-op in trust-manager bundle — `platform-apps/pki/trust-manager/templates/bundle.yaml:7`
- [x] Traefik dashboard exposed without auth middleware — `platform-apps/networking/traefik/values.yaml:28-30`
- [x] No `requirements-docs.txt` for pinned doc build deps — repo root (created when fixing item 1)
- [ ] Incomplete architecture docs with placeholder "Next Steps" — `docs/architecture/overview.md:147-150`
