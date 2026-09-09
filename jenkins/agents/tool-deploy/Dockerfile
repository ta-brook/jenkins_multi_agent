# Deploy/promotion agent image for labels docker-dev/docker-staging/docker-prod.
# Docker CLI (socket bind-mounted in clouds.yaml) + registry/env tooling only;
# the app runtime image is pulled at deploy time, never baked in here.
FROM docker:cli AS dockercli
FROM jenkins/inbound-agent:latest-jdk21

USER root

COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gettext-base \
    skopeo \
    && rm -rf /var/lib/apt/lists/*

USER jenkins
