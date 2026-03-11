FROM mcr.microsoft.com/devcontainers/dotnet:10.0-noble

ARG USERNAME=vscode

# Remove user from sudoers
RUN rm /etc/sudoers.d/${USERNAME}

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

RUN mkdir -p /home/${USERNAME}/.dotnet \
  /home/${USERNAME}/.nuget/packages && \
  chown -R ${USERNAME} /home/${USERNAME}

USER ${USERNAME}

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

USER root

# Preserve command history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/command_history/.bash_history" \
  && mkdir -p /command_history \
  && touch /command_history/.bash_history \
  && chown -R $USERNAME /command_history \
  && echo "$SNIPPET" >> /etc/bash.bashrc

USER ${USERNAME}

# Keep container alive for devcontainer to attach
CMD ["sleep", "infinity"]
