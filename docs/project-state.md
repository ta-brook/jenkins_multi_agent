# Project State — Save Point

Snapshot for resuming `jenkins_multi_agent` later.

- **Saved at commit:** `5eb5354` (`main`, pushed to origin)
- **Working tree:** clean
- **Date:** 2026-09-09

## What exists (Phase 0–6 implementation written)

| Area | Path | Notes |
|---|---|---|
| Controller image + plugins | `jenkins/controller/Dockerfile`, `plugins.txt` | jenkins/jenkins:lts-jdk21; plugin pins verified 2026-09-09 |
| JCasC config | `jenkins/controller/casc/*.yaml` | controller, security, jobs, clouds, credentials |
| Docker hosts (workers) | `jenkins/hosts/docker-host.sh`, `prune-agent-containers.sh` | Ubuntu provisioner (TLS 2376 prod / plain local) |
| Docker clouds + 4 env templates | `jenkins/controller/casc/clouds.yaml` | host-a + host-b, templates `docker-build/dev/staging/prod`, socket bind + root |
| Env-scoped credentials | `jenkins/controller/casc/credentials.yaml` | env-injected IDs: docker hosts, registry-{dev,staging,prod}, deploy-{dev,staging,prod} |
| Seed jobs | `jenkins/controller/casc/jobs.yaml` | main pipeline (SCM poll) + `smoke-docker-build` |
| Pipeline | `Jenkinsfile` (repo root) | build+test → containerize+push → dev/staging/prod gates, `TARGET_ENV` param |
| Agent images | `jenkins/agents/tool-build`, `tool-deploy`, `build-agent-images.sh` | docker CLI + tools; run script with `REGISTRY=` |
| Local harness | `jenkins/dev-harness/docker-compose.yml`, `.env.example` | controller + 2 DinD hosts + registry:5000; HTTPS dir `./https` |
| Security/ops scripts | `jenkins/security/*.sh` | keystore, docker TLS, backup/restore, plugin refresh |
| Sample app | `apps/sample-app/` | FastAPI `/health` echoes `APP_ENV`, pytest, multi-stage Dockerfile |
| Docs | `docs/architecture.md`, `docs/roadmap.md`, `docs/topologies.md`, `README.md` | baseline + ADRs + per-phase status |
| Conventions | `AGENTS.md`, `.opencode/` | commit+push per task; agents/skill define team model |

## Status

- All roadmap checkboxes Phase 0–6 are `[x]` (implementation written).
- **No acceptance criteria verified yet** — nothing was ever booted/run except
  offline syntax checks. All Phase 1–6 "Acceptance (unverified)" markers stand.

## How to continue later

1. Pull repo; state = commit `5eb5354`.
2. Ask agents (devops/swe/pm via `.opencode/agent/*.md`) or run directly.
3. Next step = **verify Phases 1–3 locally** via harness:

   ```bash
   cd jenkins/dev-harness
   cp .env.example .env          # fill GIT_REPO_URL + strong admin password
   docker compose up -d --build
   cd ../..
   REGISTRY=registry:5000 ./jenkins/agents/build-agent-images.sh
   ```
   - http://localhost:8080 (admin login), JCasC seeds jobs & clouds.
   - Run `smoke-docker-build` to prove an ephemeral `docker-build` agent works.
   - Check cloud connection (Manage Jenkins → Clouds → Test Connection).

4. Then Phase 4–6 e2e: run `jenkins_multi_agent-main` (TARGET_ENV=dev then
   staging then prod w/ approval). Accept deploys are smoke health-checks until
   a real deploy target is configured (see Jenkinsfile header + README).

## Known open items (flagged during implementation)

- JCasC docker-plugin template fields (`mounts`, `user`, `instanceCap`,
  `containerCap`) chosen from plugin docs but **unverified at boot**.
- Seed job Git URL is JCasC `${GIT_REPO_URL}` env substitution — confirm at
  first boot once `.env` has a real URL.
- Webhook trigger = SCM polling placeholder; real webhook needs live controller
  URL + SCM credentials.
- Registry/deploy targets are placeholders (local `registry:5000` + smoke-deploy).
- Backup restore drill + plugin-upgrade run not yet performed (Phase 5 acceptance).
