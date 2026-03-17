#!/bin/bash
set -e

# Remove user from sudoers
rm /etc/sudoers.d/${CONTAINER_USER}

# Install git-delta
ARCH=$(dpkg --print-architecture)
wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"
dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"
rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Create mounted directories
mkdir -p \
  /home/${CONTAINER_USER}/.dotnet \
  /home/${CONTAINER_USER}/.nuget/packages \
  /home/${CONTAINER_USER}/.claude/projects \
  /home/${CONTAINER_USER}/.claude/commands \
  /home/${CONTAINER_USER}/.claude/agents
chown -R ${CONTAINER_USER} /home/${CONTAINER_USER}

# Preserve command history across container restarts
SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/command_history/.bash_history"
mkdir -p /command_history
touch /command_history/.bash_history
chown -R ${CONTAINER_USER} /command_history
echo "$SNIPPET" >> /etc/bash.bashrc
