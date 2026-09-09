---
name: jenkins-multi-env
description: Jenkins controller + multi-environment agent design for the jenkins_multi_agent project. Use when designing or discussing Jenkins architecture (master/controller, worker/agent nodes), Docker ephemeral agent templates, multi-env setups (dev/staging/prod), JCasC, Jenkinsfile pipelines, or environment promotion. Provides the baseline topology, conventions, and decision rules the devops/swe/pm agents must follow.
---

# Jenkins Multi-Env Design (jenkins_multi_agent)

A continuous-delivery system: **1 Jenkins controller (master)** plus Docker
**ephemeral agents** serving **3 environments (dev / staging / prod)**. The
project's "2 workers" are two always-on Docker hosts that provide agent
capacity; the environments are logical, expressed through labeled Docker agent
templates and env-gated promotion, not through pinned workers.

## 1. Baseline topology (chosen)

```
                        jenkins_multi_agent
   ┌──────────────────────────────────────────────────────────────┐
   │                    CONTROL PLANE                              │
   │                                                                │
   │  ┌──────────────────────────────┐                              │
   │  │   Jenkins Controller         │                              │
   │  │   ("master", JCasC)          │  pipelines, jobs,            │
   │  │   port 8080 (UI) / 50000     │  credentials, artifacts      │
   │  └──────────────────────────────┘                              │
   │        │  inbounds agent (ssh / JNLP)                          │
   └────────┼───────────────────────────────────────────────────────┘
            │
   ┌────────▼───────────────────────────────────────────────────────┐
   │                    WORKER NODES (2 Docker hosts)               │
   │  ┌────────────────────────┐    ┌────────────────────────┐      │
   │  │   Docker Host A        │    │   Docker Host B        │      │
   │  │   (worker-1)           │    │   (worker-2)           │      │
   │  └───────────┬────────────┘    └───────────┬────────────┘      │
   └──────────────┼────────────────────────────┼────────────────────┘
                  │  spawn per-job ephemeral containers
        ┌─────────▼──────────┬──────────┬───────────────┐
        │                    │          │               │
   ┌────▼─────┐        ┌─────▼─────┐  ┌─▼──────┐   ┌────▼─────┐
   │ dev agent│        │ stage     │  │ prod   │   │ (build/  │
   │ (clean)  │        │ agent     │  │ agent  │   │  tool)   │
   │ label:   │        │ label:    │  │ label: │   │ label:   │
   │ docker-dev│       │ docker-   │  │ docker-│   │ docker-  │
   │          │        │ staging   │  │ prod   │   │ build    │
   └──────────┘        └───────────┘  └────────┘   └──────────┘
         3 logical environments = labeled Docker agent templates
```

- The controller schedules a job onto a **label** (`docker-dev`,
  `docker-staging`, `docker-prod`, or a shared `docker-build`).
- Either Docker host can run any labeled container; a job never pins to a
  specific worker by default (elasticity). If hard isolation is ever required,
  restrict an env template to one host via the docker host label.
- Each container is **ephemeral and clean** per run: no state on the worker,
  no leftover workspaces. Push state to artifacts, registries, or volumes
  declared in the template.

## 2. Decision tree (when to consider alternatives)

Full detail and diagrams for every method live in `docs/topologies.md`.

| If you need… | Prefer | Instead of |
|---|---|---|
| Fast, clean, reproducible agents with few moving parts | Docker ephemeral agents (baseline) | static VMs you must patch/clean |
| Heavy native compiles, GPU, big stateful workspaces | Static SSH agents | containers |
| Windows/MSVC/.NET builds alongside Linux | Add a static Windows service agent | a pure-Linux Docker fleet |
| Elastic scale-to-zero, per-env namespaces at cloud scale | Kubernetes pod templates | running many Docker hosts |
| Legal/regulatory isolation between envs | Controller per environment | shared controller |
| Very small demo (<5 jobs, one machine) | Controller built-in node | standing up 2 Docker hosts |

## 3. Agent template conventions

- Labels are stable and env-scoped: `docker-build`, `docker-dev`,
  `docker-staging`, `docker-prod`. Never reuse one label for two environments.
- Each template declares its runtime image. Tool images (build/test tools)
  and app images (built by `swe`) are referenced by variable so image and
  pipeline stay in sync.
- Templates mount only what is required (e.g. the workspace volume); prefer
  bind-free containers so builds are reproducible.
- Set container resource limits (CPU/memory) per template so one build cannot
  starve the Docker host.
- Keep the agent image minimal: each tool the pipeline needs should be a
  deliberate addition, not "install everything".

Example template shape (conceptual):

```yaml
# JCasC — agent node definition for the build fleet
nodes:
  - permanent:
      name: "docker-build"
      remoteFS: "/home/jenkins"
      labels: "docker-build docker-dev docker-staging docker-prod"
      launcher:
        docker:
          image: "jenkins/inbound-agent:latest"
          args: "..."
```

## 4. Pipeline & environment promotion

- **One pipeline** (`Jenkinsfile`) parameterized by target environment; do not
  duplicate the pipeline per env.
- Stages: `build` -> `test` -> `containerize` -> `push image` -> then
  env-gated promotion `deploy-dev` -> `deploy-staging` -> (manual approval) ->
  `deploy-prod`.
- **Promote immutable artifacts**: build once, tag the image once, and promote
  the same digest. Never rebuild for a promotion.
- Prod deploys require a manual approval (e.g. `input` step or an
  externally-triggered job), staged/env approval otherwise automatic.

```groovy
pipeline {
  agent { label 'docker-build' }
  parameters {
    string(name: 'ENV', defaultValue: 'dev',
           description: 'dev | staging | prod')
  }
  stages {
    stage('Build & test') { agent { label 'docker-build' } /* swe's code */ }
    stage('Push image')   { steps { sh "docker push ${IMAGE}:${GIT_COMMIT}" } }
    stage('Deploy dev')   { steps { deploy(env: 'dev',   imageDigest: IMG) } }
    stage('Deploy staging'){ steps { deploy(env: 'staging', imageDigest: IMG) } }
    stage('Deploy prod')  {
      input 'Promote to production?'
      steps { deploy(env: 'prod', imageDigest: IMG) }
    }
  }
}
```

## 5. Configuration-as-code (JCasC) & repo layout

- Everything declarative: JCasC YAML, Jenkinsfiles-as-code, job/seed DSL in
  the repo (suggest `jenkins/`).
- No click-ops config that cannot be reproduced from the repo.
- Seed the controller from a base `jenkins.yaml` (plugins, nodes, credentials
  placeholders, global settings) + a `plugins.txt`.

## 6. Credentials & security

- One credential set **per environment** (registry, deploy tokens, secrets).
  Never let dev/CI jobs read prod secrets.
- Controller keeps secrets in its credential store / secret backend; secrets
  are injected at deploy time, never baked into images or Jenkinsfiles.
- Run the controller and agents unprivileged where possible; expose only
  required ports (UI, inbound agent) to the network; TLS for UI; restrict
  script console to admins.
- Keep the controller and agent images patched; pin plugin versions in
  `plugins.txt` and have a documented upgrade path.

## 7. Controller placement, backup, upgrades

- Place the controller on its own host/VM (do not co-locate with a busy
  Docker host). Windows hosts are fine for the controller; agents stay Linux
  containers unless a static Windows agent is deliberately added.
- Backup `$JENKINS_HOME` (jobs, JCasC, credentials store, plugins config) on a
  schedule; treat the controller as disposable if fully JCasC-provisioned.
- Upgrades: snapshot, read the plugin compatibility notes, apply via JCasC +
  `plugins.txt`, verify a dev pipeline end-to-end after each upgrade.

## 8. Do / don't

- DO label every agent template by environment; labels are your env boundary.
- DO promote digests, not rebuilds.
- DO keep containers ephemeral and reproducible.
- DO keep a single source of truth for the design: `docs/architecture.md`,
  updated as ADR entries.
- DON'T run heavy builds on the controller's built-in node.
- DON'T share credentials across environments.
- DON'T depend on state left behind on a worker between runs.
