# jenkins_multi_agent — Roadmap

Owner: `pm` agent. Status per phase below; a phase is done only when its
acceptance criteria are verified. Diagrams/baseline: `architecture.md`; method
alternatives: `topologies.md`; rules and conventions: `jenkins-multi-env` skill.

## Phase 0 — Bootstrap (seed complete)

- [x] Repo scaffolding (opencode.json, agents, jenkins skill)
- [x] Baseline architecture + ADR (`architecture.md`)
- [x] Alternatives menu with diagrams (`topologies.md`)
- [ ] README pointing at these docs (optional, user request)

## Phase 1 — Jenkins controller (master)

- [ ] Choose controller OS/host and record ADR (placement, backups)
- [ ] Stand up controller; install plugins (`plugins.txt`), JCasC `jenkins.yaml`
- [ ] Base `jenkins/` layout in repo (JCasC + seed jobs as code)
- **Acceptance:** fresh controller boots fully provisioned from the repo with
  no click-ops; UI reachable over TLS; login restricted to admins.

## Phase 2 — Docker hosts (the 2 workers)

- [ ] Provision Docker Host A and Host B; register as Jenkins nodes
- [ ] Node labels + connectivity verified; agent connection documented
- [ ] Resource limits / cleanup (cron prune of stale containers)
- **Acceptance:** controller shows both hosts online; a smoke "echo" job runs
  on either host via a `docker-build` container and leaves no residue.

## Phase 3 — Ephemeral agent templates (3 envs)

- [ ] Templates: `docker-build`, `docker-dev`, `docker-staging`, `docker-prod`
- [ ] Env-scoped credential sets (registry + per-env deploy creds)
- [ ] Agent image(s) maintained in repo (Dockerfile per tool set)
- **Acceptance:** a labeled job runs inside a fresh container per env; dev
  credentials are not visible to prod-labeled jobs.

## Phase 4 — Pipeline & env-gated promotion

- [ ] Top-level `Jenkinsfile` parameterized by env (build once, promote digest)
- [ ] Stages: build+test -> containerize -> push -> dev -> staging -> prod
      (manual `input` gate before prod)
- [ ] Webhook/SCM trigger wired to the repo
- **Acceptance:** one push builds once and promotes to staging unattended; prod
  waits for manual approval; redeploy uses the same digest.

## Phase 5 — Security & ops hardening

- [ ] TLS everywhere, script console restricted, least-privilege on agents
- [ ] $JENKINS_HOME backup schedule + restore drill
- [ ] Plugin/upgrade policy and a verified upgrade run
- **Acceptance:** restore drill succeeds on a scratch controller; no default
  credentials remain.

## Phase 6 — Sample application end-to-end

- [ ] `apps/sample-app` with health endpoint + tests (swe)
- [ ] Multi-stage Dockerfile; build/test hermetic in clean containers
- [ ] End-to-end green run: push -> dev -> staging -> (approve) -> prod; health
      verified in each env
- **Acceptance:** full pipeline green from the repo README commands alone.

## Working agreement

- PM sequences and reviews each phase; devops owns Phases 1–5, swe owns the app
  parts of Phase 4/6, both report back to PM with file paths + verification.
- Each phase ends with the acceptance criteria checked, not just implemented.
