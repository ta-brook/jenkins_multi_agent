# jenkins_multi_agent — Architecture

Status: seed (v0). Baseline chosen; detailed buildout tracked in
`roadmap.md`.

## 1. Summary

A continuous-delivery system with **1 Jenkins controller (master)** and
**2 always-on Docker hosts** (the project's "workers") that spawn **ephemeral
Docker agents** for **3 environments (dev / staging / prod)**. The controller
schedules jobs onto env-scoped labels; Docker provides a clean container per
run; promotion moves immutable image digests dev -> staging -> prod with a
manual gate on production.

Decision record (why this baseline): see `topologies.md` for the full
alternatives menu and `topologies.md` model A / method 4 for the comparison.
New decisions are appended to the ADR log in section 6 below.

## 2. Topology diagram

```
                        jenkins_multi_agent
   ┌──────────────────────────────────────────────────────────────┐
   │                    CONTROL PLANE                              │
   │  ┌──────────────────────────────┐                             │
   │  │   Jenkins Controller         │                             │
   │  │   ("master", JCasC)          │  pipelines, jobs,           │
   │  │   UI 8080 / inbound 50000    │  credentials, artifacts     │
   │  └──────────────────────────────┘                             │
   │        │ inbound agent                                          │
   └────────┼───────────────────────────────────────────────────────┘
   ┌────────▼───────────────────────────────────────────────────────┐
   │                    WORKER NODES (2 Docker hosts)               │
   │  ┌────────────────────────┐    ┌────────────────────────┐      │
   │  │   Docker Host A        │    │   Docker Host B        │      │
   │  │   (worker-1)           │    │   (worker-2)           │      │
   │  └───────────┬────────────┘    └───────────┬────────────┘      │
   └──────────────┼────────────────────────────┼────────────────────┘
                  │  spawn per-job ephemeral agent containers
        ┌─────────▼─────────────┬──────────────┬──────────────┐
   ┌────▼─────┐           ┌─────▼─────┐   ┌────▼─────┐   ┌────▼─────┐
   │ build    │           │ dev agent │   │staging   │   │ prod     │
   │ agent    │           │ label:    │   │ label:   │   │ label:   │
   │ docker-  │           │ docker-dev│   │docker-   │   │ docker-  │
   │ build    │           │           │   │staging   │   │ prod     │
   └──────────┘           └───────────┘   └──────────┘   └──────────┘
          3 logical environments = labeled Docker agent templates
```

## 3. Components

| Component | Role | Provisioning / notes |
|---|---|---|
| Jenkins controller | Schedules jobs, stores credentials, JCasC, artifact & pipeline config | Own host/VM; UI 8080; inbound 50000; JCasC from repo (`jenkins/`) |
| Docker Host A (worker-1) | Agent capacity for labeled containers | Docker engine; registers with controller |
| Docker Host B (worker-2) | Agent capacity (2nd worker) | Same as A |
| Agent templates (`docker-build/dev/staging/prod`) | Env boundary; image + labels + resources | JCasC; images maintained, app image from `swe` |
| Sample app (`apps/sample-app`) | Artifact that flows through the system | Dockerfile multi-stage; health endpoint |
| Registry | Stores immutable images by digest | Per-env credentials; never share prod with dev |

## 4. Runtime flow

1. Developer pushes code -> SCM webhook triggers the top-level pipeline.
2. Pipeline runs build+test on label `docker-build`; a clean container is
   created on an available Docker host and destroyed when done.
3. `swe`'s multi-stage Dockerfile builds the app image; pipeline tags it by
   commit and pushes the digest to the registry.
4. Promotion stages deploy the **same digest**: dev (auto), staging (auto),
   prod (manual approval via `input`).
5. Each deploy injects the environment's own credentials/config at runtime;
   secrets never enter the image.

## 5. Guardrails

- Labels are the env boundary; an env template never overlaps another.
- Promote immutable digests; never rebuild for promotion.
- Containers are ephemeral and clean per run.
- Credentials are scoped per environment.
- No heavy builds on the controller's built-in node.
- Everything reproducible from the repo (JCasC + Jenkinsfile-as-code).

## 6. ADR log

| Date | Decision | Context |
|---|---|---|
| 2026-09-09 | Baseline: Docker ephemeral agents + 1 controller + 2 Docker hosts, 3 env-labeled templates (dev/staging/prod) | User spec: 1 master, 2–3 workers, multi-env; user selected Docker ephemeral agents and a 2-worker/3-env model. Alternatives in `topologies.md`. |
| 2026-09-09 | Controller image: official `jenkins/jenkins:lts` (JDK 21); plugins pinned in `jenkins/controller/plugins.txt` via `jenkins-plugin-cli`; JCasC from `jenkins/controller/casc/*.yaml` | Phase 1; everything reproducible from repo, no click-ops. Versions pinned 2026-09-09 against the official updates.jenkins.io plugin list. |
| 2026-09-09 | "Workers" = two Docker-plugin clouds (`docker-host-a`/`docker-host-b`), one per always-on Docker host; both clouds carry the same 4 env-labeled templates (`docker-build/dev/staging/prod`) | Phase 2/3; this resolves the ambiguous skill example — cloud-per-host (not controller node-per-host) is the Method-4 baseline: the controller provisions ephemeral containers on each host by label. |
| 2026-09-09 | Env boundary is the template label; credential isolation is per env ID (`registry-*`, `deploy-*`), values env-injected | Phase 3; prod credentials exist as separate IDs and are never bound to dev/staging-labeled jobs. |
| 2026-09-09 | Docker hosts speak TLS on TCP 2376 in production (`docker-host.sh`), plain 2375 only in the local `dev-harness` compose stack | Phase 2; host provisioning is a repo script; harness is local-only. |

Remaining future ADRs: registry choice (provider + URL), deploy target/port per
env (deferred to Phase 4+), backup schedule/restore drill (Phase 5), any move
toward static agents / K8s / per-env controllers.
