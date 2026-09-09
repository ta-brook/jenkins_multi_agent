# Build/test agent image for label docker-build.
# Base is the official inbound agent; docker CLI + Python toolchain added.
# The docker socket bind-mount (see clouds.yaml) lets this container build/push
# images through the same daemon the agent itself runs on.
FROM docker:cli AS dockercli
FROM jenkins/inbound-agent:latest-jdk21

USER root

COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    make \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

USER jenkins
