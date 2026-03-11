FROM mcr.microsoft.com/devcontainers/dotnet:10.0-noble

ARG CONTAINER_USER=vscode

# Remove user from sudoers
RUN rm /etc/sudoers.d/${CONTAINER_USER}

# Install git delta
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Create mounted directories
RUN mkdir -p /home/${CONTAINER_USER}/.dotnet \
  /home/${CONTAINER_USER}/.nuget/packages && \
  chown -R ${CONTAINER_USER} /home/${CONTAINER_USER}

USER ${CONTAINER_USER}

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

USER root

# Preserve command history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/command_history/.bash_history" \
  && mkdir -p /command_history \
  && touch /command_history/.bash_history \
  && chown -R ${CONTAINER_USER} /command_history \
  && echo "$SNIPPET" >> /etc/bash.bashrc

USER ${CONTAINER_USER}

# Keep container alive for devcontainer to attach
CMD ["sleep", "infinity"]
