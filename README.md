# jenkins_multi_agent

A continuous-delivery system: **1 Jenkins controller** + **2 always-on Docker
hosts** spawning **ephemeral Docker agents** for **3 environments**
(dev / staging / prod). Code is built once and the same image digest is
promoted dev -> staging -> prod, with a manual approval gate before production.

## Docs

- `docs/architecture.md` — baseline topology, components, runtime flow, ADR log
- `docs/roadmap.md` — phase-by-phase buildout status and acceptance criteria
- `docs/topologies.md` — the full menu of worker/multi-env models with diagrams
- `.opencode/skills/jenkins-multi-env/SKILL.md` — conventions agents must follow

## Repo layout

- `jenkins/controller` — controller image + `plugins.txt` + JCasC (`casc/`)
- `jenkins/hosts` — Docker-host provisioning + stale-container cleanup
- `jenkins/agents` — build/deploy agent images + build script
- `jenkins/dev-harness` — local-only compose stack (controller + 2 DinD hosts + registry)
- `jenkins/security` — TLS/keystore, Docker TLS, backups, plugin-refresh tooling
- `apps/sample-app` — FastAPI app the pipeline builds and promotes
- `Jenkinsfile` — top-level pipeline (build once, promote dev/staging/prod)

## Local quickstart (harness)

1. `cd jenkins/dev-harness && cp .env.example .env` and fill `GIT_REPO_URL`
   (this repo) plus a strong `JENKINS_ADMIN_PASSWORD`.
2. `docker compose up -d --build` — controller on http://localhost:8080
   (admin login), two Docker "hosts", and a local registry on :5000.
3. `cd ../.. && REGISTRY=registry:5000 ./jenkins/agents/build-agent-images.sh`
4. Let JCasC provision (first boot), then run the seeded
   `jenkins_multi_agent-main` job.

Prod note: the env-gated pipeline and env-scoped credentials are the real
design; the "deploy" steps run the immutable image on each env agent as a
health-checked smoke deployment. Swap that block for your real deploy target
(compose/k8s/ssh) per environment when live infra exists.

See `docs/roadmap.md` for per-phase acceptance criteria.
