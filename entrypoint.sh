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

# Validate SSH keys are accessible
if [ -d /home/coder/.ssh ] && [ -n "$(ls -A /home/coder/.ssh 2>/dev/null)" ]; then
  echo "SSH keys detected at /home/coder/.ssh" >&2
else
  echo "Warning: No SSH keys found. ~/.ssh may not be mounted or is empty." >&2
  echo "  Git operations over SSH will not work." >&2
fi

# Hand off to code-server (or whatever CMD is defined)
exec "$@"
