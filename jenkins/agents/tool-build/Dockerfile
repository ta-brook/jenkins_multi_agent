# Build/test agent image. Intended for label docker-build.
# Base is the official inbound agent; build toolchain added on top.
FROM jenkins/inbound-agent:latest-jdk21

USER root

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
