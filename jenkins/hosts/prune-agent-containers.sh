#!/usr/bin/env bash
# Remove stale ephemeral Jenkins agent containers/images left on a Docker host.
# Safe to run from cron; only touches exited containers and dangling images.
set -uo pipefail

echo "==> $(date -Is) prune-agent-containers.sh"
docker container prune -f --filter "status=exited" || true
docker image prune -f || true
echo "==> $(date -Is) disk usage after prune:"
docker system df || true
