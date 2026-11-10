# Image Jenkins kustom untuk praktikum CI/CD (Windows/macOS/Linux).
# Berisi Python 3 (syntax check), Git, curl, Docker CLI, plugin buildx, dan plugin Docker Compose.
FROM jenkins/jenkins:lts

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 curl git \
 && rm -rf /var/lib/apt/lists/*

COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx
COPY --from=docker:cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose

USER jenkins
