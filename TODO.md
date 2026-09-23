# Local Developer Platform — Improvement Backlog

## High — Security or Reliability

- [ ] Hardcoded default credentials in scaffolder template (`password`) — `spotify-templates/3-tier-app/content/backend/index.js:13`
- [ ] Backstage CI builds but never runs tests — `.github/workflows/backstage.yaml`
- [ ] CA certificate has no explicit duration/renewBefore, defaults to 90 days — `platform-apps/pki/cert-manager/templates/selfsigned-issuer.yaml:9-21`

## Medium — Consistency, Config Quality, DX

- [ ] Kargo cluster-promotion-tasks use Akuity example values, not real config — `platform-apps/orchestration/kargo/templates/cluster-promotion-tasks.yaml:8,12`
- [ ] GitHub Actions pinned to major version only, not exact — both workflow files
- [ ] pip packages not pinned in docs workflow — `.github/workflows/docs.yml:44-45`
- [ ] Backstage catalog references external GitHub, not local Gitea — `platform-apps/portal/backstage/templates/app-config.yaml:53-55`
- [ ] 3-tier-app template uses node:18-alpine (EOL) — `spotify-templates/3-tier-app/content/infra/backend.yaml:17`
- [ ] Frontend template variable syntax (`${{ values.component_id }}`) won't work in JSX — `spotify-templates/3-tier-app/content/frontend/src/App.jsx:9`
- [ ] No error handling in template frontend fetch chain — `spotify-templates/3-tier-app/content/frontend/src/App.jsx:8-14`
- [ ] Backend template leaks error details to client — `spotify-templates/3-tier-app/content/backend/index.js:34-35`

## Low — Nice to Have

- [ ] Incomplete architecture docs with placeholder "Next Steps" — `docs/architecture/overview.md:147-150`
