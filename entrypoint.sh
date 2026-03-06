#!/bin/bash
set -euo pipefail

# If HOST_HOME_DIR is set and differs from /home/coder:
# 1. Change coder's home in /etc/passwd so os.homedir() (Node.js, gosu, etc.)
#    returns the host path. This ensures tools like Lando generate Docker Compose
#    bind-mount paths the Docker daemon can resolve on the host filesystem.
# 2. Symlink all dotfiles from /home/coder into HOST_HOME_DIR so tools that
#    use HOME find their config at the expected paths.
if [ -n "${HOST_HOME_DIR:-}" ] && [ "${HOST_HOME_DIR}" != "/home/coder" ]; then
  usermod -d "${HOST_HOME_DIR}" coder
  mkdir -p "${HOST_HOME_DIR}"
  chown coder:coder "${HOST_HOME_DIR}"
  for item in /home/coder/.[!.]*; do
    name="$(basename "$item")"
    dst="${HOST_HOME_DIR}/${name}"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
      ln -s "$item" "$dst"
    fi
  done
fi

# Start dnsmasq to resolve *.lndo.site to the Docker host gateway so Lando
# development sites are reachable from inside the container.
HOST_GW=$(ip route | awk '/default/ { print $3; exit }')
if [ -n "$HOST_GW" ]; then
  echo "address=/.lndo.site/${HOST_GW}" > /etc/dnsmasq.d/lndo.conf
  dnsmasq
  # Prepend 127.0.0.1 (dnsmasq) to resolv.conf so it handles lndo.site first
  # Note: /etc/resolv.conf is a Docker bind-mount, so sed -i (rename) fails.
  # Write to the file in-place using a temp copy and cat instead.
  cp /etc/resolv.conf /tmp/resolv.conf.bak
  { echo "nameserver 127.0.0.1"; cat /tmp/resolv.conf.bak; } > /etc/resolv.conf
  rm /tmp/resolv.conf.bak
fi

# Configure git identity from environment variables
if [ -n "${GIT_USER_NAME:-}" ]; then
  gosu coder git config --global user.name "${GIT_USER_NAME}"
else
  echo "Warning: GIT_USER_NAME is not set. Git commits will use defaults." >&2
fi

if [ -n "${GIT_USER_EMAIL:-}" ]; then
  gosu coder git config --global user.email "${GIT_USER_EMAIL}"
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

# Drop to coder user and hand off to code-server (or whatever CMD is defined)
exec gosu coder "$@"
