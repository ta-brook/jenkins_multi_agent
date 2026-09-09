#!/usr/bin/env bash
# Build the agent images maintained in this repo and push them to the registry
# the Docker hosts pull from. Run from the repo root.
#   usage: REGISTRY=<host> ./jenkins/agents/build-agent-images.sh
#   e.g.   REGISTRY=registry:5000 ./jenkins/agents/build-agent-images.sh
# Then point AGENT_IMAGE_* in jenkins/controller/casc/clouds.yaml (or the
# dev-harness .env) at the pushed tags.
set -euo pipefail

REGISTRY="${REGISTRY:?set REGISTRY, e.g. REGISTRY=registry:5000}"
NAMESPACE="${NAMESPACE:-jenkins-multi-agent}"
TAG="${TAG:-latest}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

build_and_push() {
  local name="$1" dir="$2"
  local img="$REGISTRY/$NAMESPACE/$name:$TAG"
  echo "==> building $img from $dir"
  docker build -t "$img" "$ROOT/$dir"
  echo "==> pushing $img"
  docker push "$img"
}

build_and_push "tool-build"  "jenkins/agents/tool-build"
build_and_push "tool-deploy" "jenkins/agents/tool-deploy"

echo "==> done. Use images:"
echo "    $REGISTRY/$NAMESPACE/tool-build:$TAG"
echo "    $REGISTRY/$NAMESPACE/tool-deploy:$TAG"
