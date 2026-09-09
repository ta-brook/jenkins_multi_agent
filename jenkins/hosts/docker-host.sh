#!/usr/bin/env bash
# Provision a Jenkins Docker host (the project's "worker").
# Usage: sudo ./docker-host.sh <host-id> [docker-host-ip-or-fqdn]
#   <host-id>            e.g. worker-1 or worker-2 (becomes the docker node label)
#   [host-ip-or-fqdn]    address the Jenkins controller will reach this host on.
#                        If given, the Docker daemon listens on TCP 2376 (TLS).
#                        If omitted, the daemon listens on the unix socket only.
set -euo pipefail

HOST_ID="${1:?usage: docker-host.sh <host-id> [host-ip-or-fqdn]}"
HOST_ADDR="${2:-}"

echo "==> docker-host.sh: provisioning '$HOST_ID'"

# --- install Docker engine (Ubuntu/Debian) ---
if ! command -v docker >/dev/null 2>&1; then
  echo "==> installing Docker engine"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# --- daemon settings: log rotation + resource guardrails ---
DAEMON_JSON=/etc/docker/daemon.json
if [ ! -f "$DAEMON_JSON" ]; then
  echo "==> writing $DAEMON_JSON"
  if [ -n "$HOST_ADDR" ]; then
    mkdir -p /etc/docker
    cat > "$DAEMON_JSON" <<EOF
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2376"],
  "tls": true,
  "tlscacert": "/etc/docker/tls/ca.pem",
  "tlscert": "/etc/docker/tls/server-cert.pem",
  "tlskey": "/etc/docker/tls/server-key.pem",
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" }
}
EOF
  else
    cat > "$DAEMON_JSON" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" }
}
EOF
  fi
fi

# --- Docker labels so the controller's clouds can pin hosts if desired ---
echo "==> applying host labels (needs docker daemon start)"
systemctl enable --now docker 2>/dev/null || true
docker network inspect jenkins >/dev/null 2>&1 || docker network create jenkins || true

# --- periodic cleanup of stale ephemeral agent containers ---
PRUNE=/usr/local/sbin/prune-agent-containers.sh
install -m 0755 "$(dirname "$0")/prune-agent-containers.sh" "$PRUNE"
CRON="*/15 * * * * $PRUNE"
( crontab -l 2>/dev/null | grep -v -F "$PRUNE" ; echo "$CRON" ) | crontab -

echo "==> done provisioning '$HOST_ID'"
echo "    Add this host's name+address as a Docker cloud named e.g. 'docker-host-${HOST_ID##*-}'"
echo "    in jenkins/controller/casc/clouds.yaml (uri tcp://$HOST_ADDR:2376)."
