#!/bin/bash
set -euo pipefail

# Configure git identity from environment variables
if [ -n "${GIT_USER_NAME:-}" ]; then
  git config --global user.name "${GIT_USER_NAME}"
else
  echo "Warning: GIT_USER_NAME is not set. Git commits will use defaults." >&2
fi

if [ -n "${GIT_USER_EMAIL:-}" ]; then
  git config --global user.email "${GIT_USER_EMAIL}"
else
  echo "Warning: GIT_USER_EMAIL is not set. Git commits will use defaults." >&2
fi

# Validate SSH agent socket
if [ -n "${SSH_AUTH_SOCK:-}" ]; then
  if [ ! -S "${SSH_AUTH_SOCK}" ]; then
    echo "Warning: SSH_AUTH_SOCK is set to '${SSH_AUTH_SOCK}' but the socket does not exist." >&2
    echo "  SSH agent forwarding will not work. Check that your SSH agent is running" >&2
    echo "  and update SSH_AUTH_SOCK in .env if the path has changed." >&2
  fi
else
  echo "Warning: SSH_AUTH_SOCK is not set. SSH agent forwarding is disabled." >&2
fi

# Hand off to code-server (or whatever CMD is defined)
exec "$@"
