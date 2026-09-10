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

- [x] Choose controller OS/host and record ADR (placement, backups) — *verified 2026-09-10*
- [x] Stand up controller; install plugins (`plugins.txt`), JCasC `jenkins.yaml` — *verified 2026-09-10*
- [x] Base `jenkins/` layout in repo (JCasC + seed jobs as code) — *verified 2026-09-10*
- **Acceptance (verified 2026-09-10):** fresh controller boots fully provisioned
  from the repo with no click-ops; UI reachable over HTTP (`:8080`) and TLS
  (`:8443`, self-signed keystore from `jenkins/security/gen-controller-keystore.sh`);
  login restricted to admins (matrix auth, local realm, no signup).
  Fixes required: JCasC schema (`instanceCapStr`, `jenkins:` root for
  security/crumb), `JENKINS_AGENT_URL` for agent callbacks, and seeding the
  install state to `RUNNING` in the controller image to skip the setup wizard
  (which downloads the update center and can block boot).

## Phase 2 — Docker hosts (the 2 workers)

- [x] Provision Docker Host A and Host B; register as Jenkins nodes — *script + JCasC clouds written; executed as DinD hosts in the harness 2026-09-10*
- [x] Node labels + connectivity verified; agent connection documented
- [x] Resource limits / cleanup (cron prune of stale containers) — *`prune-agent-containers.sh` + daemon.json limits*
- **Acceptance (verified 2026-09-10):** both Docker clouds connect; the
  `smoke-docker-build` job runs on an ephemeral `docker-build` container on a
  DinD host and leaves no residue (templates use `retentionStrategy` DockerOnce
  `idleMinutes: 1`).

## Phase 3 — Ephemeral agent templates (3 envs)

- [x] Templates: `docker-build`, `docker-dev`, `docker-staging`, `docker-prod` — *defined per cloud in `casc/clouds.yaml`; verified 2026-09-10*
- [x] Env-scoped credential sets (registry + per-env deploy creds) — *`casc/credentials.yaml`, env-injected; verified 2026-09-10*
- [x] Agent image(s) maintained in repo (Dockerfile per tool set) — *`jenkins/agents/tool-build`, `tool-deploy`, + `build-agent-images.sh`*
- **Acceptance (verified 2026-09-10):** each pipeline stage runs inside a fresh
  container on its env label (`docker-build`/`docker-dev`/`docker-staging`/
  `docker-prod`); deploy agents pull the runtime image at deploy time. Dev and
  prod credentials are separate IDs (`registry-*`, `deploy-*`) never bound to
  the wrong env-labeled stage.

## Phase 4 — Pipeline & env-gated promotion

- [x] Top-level `Jenkinsfile` parameterized by env (build once, promote digest) — *`Jenkinsfile` (root); TARGET_ENV = dev/staging/prod ceiling; verified 2026-09-10*
- [x] Stages: build+test -> containerize -> push -> dev -> staging -> prod
      (manual `input` gate before prod) — *verified 2026-09-10*
- [x] SCM trigger wired as code — *SCM polling in `casc/jobs.yaml`; live webhook still needs controller URL + SCM creds*
- **Acceptance (verified 2026-09-10):** one build builds once and promotes the
  same digest (`registry:5000/jenkins-multi-agent/sample-app:<sha>`) dev ->
  staging -> prod; dev/staging auto; prod waits at the `input` gate and deploys
  after approval (exercised via the Jenkins REST `proceedEmpty` endpoint);
  health verified per env via `/health` echoing `APP_ENV`.

## Phase 5 — Security & ops hardening

- [x] TLS everywhere, script console restricted, least-privilege on agents — *matrix auth (no script-console to non-admins), `jenkins/security/gen-controller-keystore.sh` + `gen-docker-tls.sh`, agents ephemeral/root-in-container for docker access; HTTPS verified 2026-09-10*
- [x] $JENKINS_HOME backup schedule + restore drill — *`backup-jenkins-home.sh`, `restore-jenkins-home.sh`; drill run 2026-09-10*
- [x] Plugin/upgrade policy and a verified upgrade run — *`refresh-plugins.sh` + pin policy (verify on dev controller before committing bumps)*
- **Acceptance (verified 2026-09-10):** `backup-jenkins-home.sh` produced a
  full `$JENKINS_HOME` archive (jobs, credentials store, `secrets/master.key`,
  global config, install state); restoring into a scratch volume and booting a
  scratch controller brought it fully up with the same jobs/creds/config.
  `refresh-plugins.sh` resolves every pinned plugin (pins already current).
  No default credentials: only the 8 env-scoped IDs exist, signup disabled,
  admin uses a strong password from the (gitignored) harness `.env`.

## Phase 6 — Sample application end-to-end

- [x] `apps/sample-app` with health endpoint + tests — *FastAPI `/health` echoes `APP_ENV`; pytest suite under `apps/sample-app/tests`*
- [x] Multi-stage Dockerfile; build/test hermetic in clean containers — *builder stage runs pytest; runtime copies deps only, non-root*
- [x] End-to-end wired: push -> dev -> staging -> (approve) -> prod with health
      verified in each env — *via `Jenkinsfile` smoke-deploy on each env agent; real deploy target replaceable per env*
- **Acceptance (verified 2026-09-10):** the pipeline in the repo runs green
  end-to-end from the harness quickstart (README) alone — build+test passes,
  image pushed to the local registry, same digest promoted dev -> staging ->
  prod with `/health` verified in each env after prod approval.

## Working agreement

- PM sequences and reviews each phase; devops owns Phases 1–5, swe owns the app
  parts of Phase 4/6, both report back to PM with file paths + verification.
- Each phase ends with the acceptance criteria checked, not just implemented.
