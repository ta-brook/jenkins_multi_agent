# Deploy/promotion agent image. Intended for labels docker-dev/staging/prod.
# Holds registry + env tooling only; runtime app code is NOT baked in here.
FROM jenkins/inbound-agent:latest-jdk21

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gettext-base \
    skopeo \
    && rm -rf /var/lib/apt/lists/*

USER jenkins
