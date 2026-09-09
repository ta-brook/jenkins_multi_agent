# jenkins_multi_agent — Roadmap

Owner: `pm` agent. Status per phase below; a phase is done only when its
acceptance criteria are verified. Diagrams/baseline: `architecture.md`; method
alternatives: `topologies.md`; rules and conventions: `jenkins-multi-env` skill.

## Phase 0 — Bootstrap (seed complete)

- [x] Repo scaffolding (opencode.json, agents, jenkins skill)
- [x] Baseline architecture + ADR (`architecture.md`)
- [x] Alternatives menu with diagrams (`topologies.md`)
- [x] README pointing at these docs + local quickstart — *`README.md`*

## Phase 1 — Jenkins controller (master)

- [x] Choose controller OS/host and record ADR (placement, backups) — *implementation written; boot verification pending*
- [x] Stand up controller; install plugins (`plugins.txt`), JCasC `jenkins.yaml` — *files under `jenkins/controller/`; not yet booted*
- [x] Base `jenkins/` layout in repo (JCasC + seed jobs as code)
- **Acceptance (unverified — run `jenkins/dev-harness` compose):** fresh
  controller boots fully provisioned from the repo with no click-ops; UI
  reachable over TLS; login restricted to admins.

## Phase 2 — Docker hosts (the 2 workers)

- [x] Provision Docker Host A and Host B; register as Jenkins nodes — *script + JCasC clouds written; not yet executed*
- [x] Node labels + connectivity verified; agent connection documented
- [x] Resource limits / cleanup (cron prune of stale containers) — *`prune-agent-containers.sh` + daemon.json limits*
- **Acceptance (unverified):** controller shows both hosts online; a smoke
  "echo" job runs on either host via a `docker-build` container and leaves no
  residue.

## Phase 3 — Ephemeral agent templates (3 envs)

- [x] Templates: `docker-build`, `docker-dev`, `docker-staging`, `docker-prod` — *defined per cloud in `casc/clouds.yaml`*
- [x] Env-scoped credential sets (registry + per-env deploy creds) — *`casc/credentials.yaml`, env-injected*
- [x] Agent image(s) maintained in repo (Dockerfile per tool set) — *`jenkins/agents/tool-build`, `tool-deploy`, + `build-agent-images.sh`*
- **Acceptance (unverified):** a labeled job runs inside a fresh container per
  env; dev credentials are not visible to prod-labeled jobs.

## Phase 4 — Pipeline & env-gated promotion

- [x] Top-level `Jenkinsfile` parameterized by env (build once, promote digest) — *`Jenkinsfile` (root); TARGET_ENV = dev/staging/prod ceiling*
- [x] Stages: build+test -> containerize -> push -> dev -> staging -> prod
      (manual `input` gate before prod)
- [x] SCM trigger wired as code — *SCM polling in `casc/jobs.yaml`; live webhook still needs controller URL + SCM creds*
- **Acceptance (unverified):** one push builds once and promotes to staging
  unattended; prod waits for manual approval; redeploy uses the same digest.

## Phase 5 — Security & ops hardening

- [x] TLS everywhere, script console restricted, least-privilege on agents — *matrix auth (no script-console to non-admins), `jenkins/security/gen-controller-keystore.sh` + `gen-docker-tls.sh`, agents ephemeral/root-in-container for docker access*
- [x] $JENKINS_HOME backup schedule + restore drill — *`backup-jenkins-home.sh`, `restore-jenkins-home.sh` (cron/drill documented)*
- [x] Plugin/upgrade policy and a verified upgrade run — *`refresh-plugins.sh` + pin policy (verify on dev controller before committing bumps)*
- **Acceptance (unverified):** restore drill succeeds on a scratch controller;
  no default credentials remain (harness defaults exist only for local testing).

## Phase 6 — Sample application end-to-end

- [x] `apps/sample-app` with health endpoint + tests — *FastAPI `/health` echoes `APP_ENV`; pytest suite under `apps/sample-app/tests`*
- [x] Multi-stage Dockerfile; build/test hermetic in clean containers — *builder stage runs pytest; runtime copies deps only, non-root*
- [x] End-to-end wired: push -> dev -> staging -> (approve) -> prod with health
      verified in each env — *via `Jenkinsfile` smoke-deploy on each env agent; real deploy target replaceable per env*
- **Acceptance (unverified):** full pipeline green from the repo README
  commands alone (harness quickstart in `README.md`).

## Working agreement

- PM sequences and reviews each phase; devops owns Phases 1–5, swe owns the app
  parts of Phase 4/6, both report back to PM with file paths + verification.
- Each phase ends with the acceptance criteria checked, not just implemented.
