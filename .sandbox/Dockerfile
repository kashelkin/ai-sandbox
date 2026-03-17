ARG SANDBOX_IMAGE=mcr.microsoft.com/devcontainers/dotnet:10.0-noble
FROM ${SANDBOX_IMAGE}

ARG CONTAINER_USER=vscode
ARG GIT_DELTA_VERSION=0.18.2

# Expose build args as env vars so init scripts can reference them
ENV CONTAINER_USER=${CONTAINER_USER} \
    GIT_DELTA_VERSION=${GIT_DELTA_VERSION}

COPY scripts/ /tmp/scripts/

RUN chmod +x /tmp/scripts/*.sh && /tmp/scripts/init-root.sh

USER ${CONTAINER_USER}

RUN /tmp/scripts/init-user.sh

USER root

RUN rm -rf /tmp/scripts

USER ${CONTAINER_USER}

# Keep container alive for devcontainer to attach
CMD ["sleep", "infinity"]
