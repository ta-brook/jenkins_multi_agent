# Testing Guide — Jenkins Multi-Env "in action"

Hands-on, copy-paste walkthrough to exercise every phase of
`jenkins_multi_agent` against the local harness. Each step lists the command,
what you should see, and what it proves.

Harness = 1 Jenkins controller + 2 Docker-in-Docker "worker" hosts + a local
registry, all in containers. The pipeline builds once and promotes the same
image digest dev -> staging -> prod.

> Shell examples are PowerShell 5.1 (the verified environment). Replace the
> `$ADMIN` password value with the one from your `jenkins/dev-harness/.env`
> (`JENKINS_ADMIN_PASSWORD=...`).

---

## 0. Start the harness

```powershell
cd jenkins/dev-harness
Copy-Item .env.example .env      # then edit .env: GIT_REPO_URL + strong JENKINS_ADMIN_PASSWORD
docker compose up -d --build     # controller on :8080, DinD hosts, registry :5000
```

Push the agent images. Push via `localhost:5000` (resolvable from your machine);
the DinD hosts pull them as `registry:5000/...`:

```powershell
docker build -t localhost:5000/jenkins-multi-agent/tool-build:latest  ../agents/tool-build
docker push  localhost:5000/jenkins-multi-agent/tool-build:latest
docker build -t localhost:5000/jenkins-multi-agent/tool-deploy:latest ../agents/tool-deploy
docker push  localhost:5000/jenkins-multi-agent/tool-deploy:latest
```

Wait for the controller to finish provisioning, then confirm it is up:

```powershell
Start-Sleep -Seconds 75
curl.exe -s -o NUL -w "%{http_code}`n" http://localhost:8080/login     # expect 200
```

**Proves:** repo-driven startup — controller boots fully provisioned from JCasC.

---

## 1. Test the controller (Phase 1)

| Check | How | Expect |
|---|---|---|
| UI reachable | Open http://localhost:8080 | Jenkins login page (no setup wizard) |
| Login restricted | Log in as `admin` / password from `.env` | Dashboard loads; no "create admin" wizard |
| Jobs seeded as code | Dashboard | `jenkins_multi_agent-main` and `smoke-docker-build` |
| TLS | http://localhost:8443 (accept self-signed) | Login page over HTTPS |

Prove admin-only security and that signup is off:

```powershell
$ADMIN="<value of JENKINS_ADMIN_PASSWORD from .env>"
$b=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:$ADMIN"))
$h=@{ Authorization = "Basic $b" }
Invoke-RestMethod -Uri "http://localhost:8080/api/json?tree=jobs[name]" -Headers $h |
  Select-Object -ExpandProperty jobs
# expect: jenkins_multi_agent-main, smoke-docker-build
```

**Proves:** Phase 1 acceptance — fully provisioned from the repo, no click-ops,
TLS, admin-only.

---

## 2. Test the Docker hosts + ephemeral agents (Phases 2–3)

Check both clouds are connected:

```powershell
# UI: Manage Jenkins -> Clouds  (docker-host-a, docker-host-b, no red warnings)
```

Run the smoke job and watch it land on a fresh ephemeral agent:

```powershell
# UI: Dashboard -> smoke-docker-build -> Build Now, then open the build console
# expect: "Building remotely on docker-build-XXXX on docker-host-a" and
#         "smoke ok on <container-id>"
```

Confirm no residue left behind (the agent container is removed ~1 min after the run):

```powershell
docker exec -e DOCKER_HOST=tcp://localhost:2375 docker-host-a docker ps -a   # empty (or only exited)
docker exec -e DOCKER_HOST=tcp://localhost:2375 docker-host-b docker ps -a   # empty
```

Check the env-scoped credential isolation design (8 IDs, one set per env):

```powershell
Invoke-RestMethod -Uri "http://localhost:8080/credentials/store/system/domain/_/api/json?tree=credentials[id]" -Headers $h |
  Select-Object -ExpandProperty credentials | Select-Object -ExpandProperty id
# expect: docker-host-a, docker-host-b,
#         registry-dev, registry-staging, registry-prod,
#         deploy-dev,   deploy-staging,   deploy-prod
```

**Proves:** Phases 2–3 — both hosts online, labeled ephemeral agents, no
residue, per-env credentials.

---

## 3. Test the pipeline end-to-end (Phases 4 & 6)

### 3a. Dev + staging (automatic)

```powershell
# UI: jenkins_multi_agent-main -> Build with Parameters -> TARGET_ENV=dev -> Build
```

Open the build console and confirm, in order:

1. **Build & test** on a `docker-build` agent — `3 passed`
2. **Containerize & push** — `docker build` then `docker push registry:5000/jenkins-multi-agent/sample-app:<sha>`
3. **Deploy dev** — `health ok in dev`

Then run again with `TARGET_ENV=staging` and confirm it additionally does
`Deploy staging` -> `health ok in staging`, using the **same image digest**.

### 3b. Prod with approval gate

```powershell
# UI: Build with Parameters -> TARGET_ENV=prod -> Build
```

Watch it deploy dev and staging automatically, then **pause**:

```
[Pipeline] input
Promote to production?
Promote or Abort
```

Approve **in the UI** (click *Promote*) and confirm `health ok in prod`.

Or approve **over the REST API** (repeatable/scripted):

```powershell
$build=2   # this run's build number
$crumb=(Invoke-RestMethod -Uri "http://localhost:8080/crumbIssuer/api/json" -Headers $h).crumb
$script="def r=Jenkins.instance.getItemByFullName('jenkins_multi_agent-main').getBuildByNumber($build);" +
        "def a=r.getAction(org.jenkinsci.plugins.workflow.support.steps.input.InputAction.class);" +
        "a.getExecutions().each { println 'IDX='+it.getId() }"
$id=([regex]::Match((Invoke-RestMethod -Uri "http://localhost:8080/scriptText" -Method Post -Headers @{Authorization="Basic $b";"Jenkins-Crumb"=$crumb} -Body @{script=$script}), 'IDX=([0-9a-f]{32})')).Groups[1].Value
Invoke-RestMethod -Uri "http://localhost:8080/job/jenkins_multi_agent-main/$build/input/$id/proceedEmpty" `
  -Method Post -Headers @{ Authorization="Basic $b"; "Jenkins-Crumb"=$crumb }
# build then finishes with: "Approved by Jenkins Admin" -> "health ok in prod" -> Finished: SUCCESS
```

Verify the **same digest** was used everywhere (search the console for
`Promoting image` and the `docker pull` lines in each deploy stage).

**Proves:** Phases 4 & 6 — build once, promote immutable digest
dev -> staging -> prod, manual gate on prod, health-checked in each env.

---

## 4. Test security & ops (Phase 5)

### HTTPS
`https://localhost:8443` loads the login page (self-signed cert OK for the
harness). The keystore is generated by:

```powershell
# one-off container (has keytool), writes into jenkins/dev-harness/https/
$pw="change-me-keystore-password"
docker run --rm -v "$PWD/https:/out" jenkins-multi-agent-controller keytool -genkeypair `
  -alias jenkins -keyalg RSA -keysize 3072 -storetype PKCS12 `
  -keystore /out/keystore.p12 -storepass $pw -keypass $pw `
  -dname "CN=localhost, OU=jenkins-multi-agent, O=jenkins-multi-agent, C=" -validity 365
```
Then set `JENKINS_OPTS` in `.env` (see `.env.example`) and restart the controller.

### Backup / restore drill
Backup the live `$JENKINS_HOME` (jobs, credentials store, master key, config):

```powershell
docker volume create jma-backups
docker run --rm -u root --entrypoint bash `
  -v jenkins-multi-agent_jenkins_home:/var/jenkins_home:ro `
  -v jma-backups:/backups `
  -v "$PWD\..\security:/scripts:ro" `
  jenkins-multi-agent-controller /scripts/backup-jenkins-home.sh /var/jenkins_home /backups 3
# expect: ==> backing up ... -> /backups/jenkins-home-<stamp>.tar.gz
```

Verify the archive holds the essentials:

```powershell
docker run --rm -u root --entrypoint sh -v jma-backups:/backups:ro jenkins-multi-agent-controller -c `
  "tar tzf /backups/jenkins-home-*.tar.gz | grep -E 'credentials.xml|secrets/master.key|jobs/.*/config.xml' | head"
```

Restore into a scratch controller and boot it:

```powershell
docker volume create jma-scratch
docker run --rm -u root --entrypoint sh -v jma-backups:/backups:ro -v jma-scratch:/scratch `
  jenkins-multi-agent-controller -c "tar xzf /backups/jenkins-home-*.tar.gz -C /scratch"
docker run --rm -u root -v jma-scratch:/var/jenkins_home jenkins-multi-agent-controller chown -R jenkins:jenkins /var/jenkins_home
docker run -d --name jma-scratch -v jma-scratch:/var/jenkins_home `
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc `
  -e JENKINS_URL=http://localhost:8080 -e JENKINS_ADMIN_PASSWORD=$ADMIN `
  -e GIT_REPO_URL=https://github.com/ta-brook/jenkins_multi_agent.git `
  -e AGENT_IMAGE_TOOL_BUILD=registry:5000/jenkins-multi-agent/tool-build:latest `
  --network jenkins-multi-agent jenkins-multi-agent-controller
Start-Sleep -Seconds 75
docker exec jma-scratch curl -s -o /dev/null -w "%{http_code}`n" http://localhost:8080/login   # expect 200
docker rm -f jma-scratch
docker volume rm jma-scratch
```

**Proves:** restore drill — a replacement controller boots from the backup with
jobs, credentials, and config intact.

### Plugin refresh path
```powershell
docker run --rm -v "$PWD\..:/repo:ro" python:3.14-slim bash /repo/jenkins/security/refresh-plugins.sh
# prints the current plugin pins (already latest); add --write to update plugins.txt
```

### No default credentials
The only credentials are the 8 env-scoped IDs (step 2), signup is disabled, and
the admin password is the strong one from your (gitignored) `.env`.

---

## 5. Inspect the moving parts

```powershell
# Local registry contents
curl.exe -s http://localhost:5000/v2/_catalog
curl.exe -s http://localhost:5000/v2/jenkins-multi-agent/sample-app/tags/list

# Containers running on each "worker" (ephemeral agents + deploy smoke runs)
docker exec -e DOCKER_HOST=tcp://localhost:2375 docker-host-a docker ps
docker exec -e DOCKER_HOST=tcp://localhost:2375 docker-host-b docker ps

# Controller logs (JCasC, provisioning, SCM triggers)
docker logs jenkins-controller --tail 50
```

---

## 6. Tear down / start over

```powershell
docker compose down          # stop the harness (keeps volumes)
docker compose down -v       # also wipe jenkins_home, host, and registry data
```

A `-v` wipe gives you the true fresh-boot test from section 0.

---

## Expected end state (all green)

- Controller: HTTP `:8080` and HTTPS `:8443` = 200.
- `smoke-docker-build`: SUCCESS on an ephemeral `docker-build` container; both
  hosts empty afterwards.
- `jenkins_multi_agent-main` (TARGET_ENV=prod): SUCCESS — build+test 3 passed,
  one image pushed, `health ok in dev|staging|prod`, same digest throughout,
  prod reached only after the input gate is approved.
- Backup/restore drill boots a scratch controller from the archive.