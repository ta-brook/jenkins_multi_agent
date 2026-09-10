# Project State — Save Point

Snapshot for resuming `jenkins_multi_agent` later.

- **Saved at commit:** `350e27e` (includes verification commits `0906449`, `df80a2b`, and the testing guide)
- **Working tree:** clean
- **Date:** 2026-09-10

## What exists and is verified (Phase 0–6)

| Area | Path | Status |
|---|---|---|
| Controller image + plugins | `jenkins/controller/Dockerfile`, `plugins.txt` | jenkins/jenkins:lts-jdk21; install state seeded to `RUNNING` (skips setup wizard); HTTPS keystore via `gen-controller-keystore.sh` |
| JCasC config | `jenkins/controller/casc/*.yaml` | boots clean; `instanceCapStr`, `jenkins:` root for security/crumb, `JENKINS_AGENT_URL` for agent callbacks, DockerOnce `idleMinutes: 1` retention |
| Docker hosts (workers) | `jenkins/hosts/docker-host.sh`, `prune-agent-containers.sh` | exercised as DinD hosts in the harness |
| Docker clouds + 4 env templates | `jenkins/controller/casc/clouds.yaml` | both clouds connect; ephemeral agents on both hosts by label |
| Env-scoped credentials | `jenkins/controller/casc/credentials.yaml` | 8 IDs verified (`docker-host-a/b`, `registry-*`, `deploy-*`) |
| Seed jobs | `jenkins/controller/casc/jobs.yaml` | main pipeline (SCM poll + params seeded) + `smoke-docker-build` (freestyle) |
| Pipeline | `Jenkinsfile` (repo root) | build+test → containerize+push → dev/staging/prod gates; `${VAR:-}`-safe; post `cleanWs` node-wrapped |
| Agent images | `jenkins/agents/tool-build`, `tool-deploy`, `build-agent-images.sh` | built/pushed to `localhost:5000` (host) / `registry:5000` (DinD) |
| Local harness | `jenkins/dev-harness/docker-compose.yml`, `.env.example` | controller + 2 DinD hosts (unix socket exposed) + registry; fixed controller IP `172.31.0.10`; `.env` + `https/` gitignored |
| Security/ops scripts | `jenkins/security/*.sh` | keystore, docker TLS, backup/restore, plugin refresh |
| Sample app | `apps/sample-app/` | FastAPI `/health` echoes `APP_ENV`; pytest passes inside the image build |
| Docs | `docs/architecture.md`, `docs/roadmap.md`, `docs/topologies.md`, `docs/testing.md`, `README.md` | all Phase 1–6 acceptances marked verified; `testing.md` is a hands-on "test in action" walkthrough |
| Conventions | `AGENTS.md`, `.opencode/` | commit+push per task; agents/skill define team model |

## Verification results (2026-09-10, Docker Desktop 29.7.2, 8 GB / 12 CPU)

- **Phase 1:** fresh controller boots fully provisioned from repo, no wizard,
  no click-ops. HTTP :8080 and HTTPS :8443 both reachable. Admin-only login.
- **Phase 2:** both Docker clouds connect; `smoke-docker-build` runs on an
  ephemeral `docker-build` container and leaves no residue.
- **Phase 3:** stages run on env-labeled fresh containers
  (`docker-build`/`-dev`/`-staging`/`-prod`); per-env credential IDs enforced by
  the pipeline.
- **Phase 4/6:** one build pushed
  `registry:5000/jenkins-multi-agent/sample-app:09064490…` and promoted the same
  digest dev → staging → prod; prod waited at the `input` gate and was approved
  over the REST API (`/input/<id>/proceedEmpty`); `/health` echoed the right env
  in each stage.
- **Phase 5:** HTTPS verified; `backup-jenkins-home.sh` → full archive (jobs,
  credentials, `secrets/master.key`, config, install state) → restored into a
  scratch volume → scratch controller booted fully up. `refresh-plugins.sh`
  resolves all pins (already current). No default credentials; strong admin
  password lives in the gitignored harness `.env`.

## How to continue later

1. Pull repo; state = verified Phase 0–6 at `350e27e` (see `git log`).
2. Harness: `cd jenkins/dev-harness && cp .env.example .env` (fill
   `GIT_REPO_URL` + strong `JENKINS_ADMIN_PASSWORD`; optionally enable HTTPS in
   `JENKINS_OPTS`), `docker compose up -d --build`,
   `docker build -t localhost:5000/jenkins-multi-agent/tool-build:latest ../agents/tool-build` (+ tool-deploy), push both.
3. Follow `docs/testing.md` for the hands-on walkthrough: login, run
   `smoke-docker-build`, then `jenkins_multi_agent-main` (default
   `TARGET_ENV=prod`; approve the input via the UI or the REST `proceedEmpty`
   endpoint).
4. Real hosts/prod: swap the DinD hosts for `docker-host.sh` workers (TLS 2376),
   point the registry/deploy targets at real infra, and wire a real webhook.

## Known open items (post-verification)

- Live webhook (SCM polling placeholder) needs a real controller URL + SCM creds.
- Registry/deploy targets are placeholders (local `registry:5000` + smoke-deploy).
- Docker-plugin `DockerOnceRetentionStrategy` normalizes `idleMinutes: 0` to `10`;
  the harness pins `1` so agents reclaim ~1 min after a run.
- Boot is reliable with the install-state seed; the Jenkins setup-wizard update
  download is skipped entirely (it could block init on slow networks).
- Backup/restore and plugin-refresh runs are exercised on the harness; a
  production backup schedule + upgrade run should be scheduled against real
  infra.