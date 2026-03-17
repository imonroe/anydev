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

# --- Claude Code configuration: symlink commands/agents, merge base settings ---
CLAUDE_CONFIG_REPO="/home/coder/claude-config"
CLAUDE_CONFIG_HOME="/home/coder/.claude"

if [ -d "$CLAUDE_CONFIG_REPO" ]; then
  # Symlink commands: repo files take precedence, existing extras are preserved
  if [ -d "$CLAUDE_CONFIG_REPO/commands" ]; then
    mkdir -p "$CLAUDE_CONFIG_HOME/commands"
    for f in "$CLAUDE_CONFIG_REPO/commands"/*; do
      [ -e "$f" ] || continue
      target="$CLAUDE_CONFIG_HOME/commands/$(basename "$f")"
      # Replace regular files with symlinks; leave existing symlinks alone
      if [ -f "$target" ] && [ ! -L "$target" ]; then
        rm "$target"
      fi
      if [ ! -e "$target" ]; then
        ln -s "$f" "$target"
      fi
    done
  fi

  # Symlink agents: same logic
  if [ -d "$CLAUDE_CONFIG_REPO/agents" ]; then
    mkdir -p "$CLAUDE_CONFIG_HOME/agents"
    for f in "$CLAUDE_CONFIG_REPO/agents"/*; do
      [ -e "$f" ] || continue
      target="$CLAUDE_CONFIG_HOME/agents/$(basename "$f")"
      if [ -f "$target" ] && [ ! -L "$target" ]; then
        rm "$target"
      fi
      if [ ! -e "$target" ]; then
        ln -s "$f" "$target"
      fi
    done
  fi

  # Symlink default_mcp.json
  if [ -f "$CLAUDE_CONFIG_REPO/default_mcp.json" ]; then
    if [ -f "$CLAUDE_CONFIG_HOME/default_mcp.json" ] && [ ! -L "$CLAUDE_CONFIG_HOME/default_mcp.json" ]; then
      rm "$CLAUDE_CONFIG_HOME/default_mcp.json"
    fi
    if [ ! -e "$CLAUDE_CONFIG_HOME/default_mcp.json" ]; then
      ln -s "$CLAUDE_CONFIG_REPO/default_mcp.json" "$CLAUDE_CONFIG_HOME/default_mcp.json"
    fi
  fi

  # Merge base settings: repo provides hooks/model/plugins, existing permissions preserved
  if [ -f "$CLAUDE_CONFIG_REPO/settings.json" ]; then
    EXISTING="$CLAUDE_CONFIG_HOME/settings.json"
    BASE="$CLAUDE_CONFIG_REPO/settings.json"
    if [ -f "$EXISTING" ]; then
      # Merge: base settings win for everything except permissions (which come from existing)
      python3 -c "
import json, sys
with open(sys.argv[1]) as f: base = json.load(f)
with open(sys.argv[2]) as f: existing = json.load(f)
if 'permissions' in existing:
    base['permissions'] = existing['permissions']
out = json.dumps(base, indent=2) + '\n'
with open(sys.argv[2], 'w') as f: f.write(out)
" "$BASE" "$EXISTING"
      echo "Claude Code settings merged (base + local permissions)." >&2
    else
      cp "$BASE" "$EXISTING"
      echo "Claude Code settings initialized from base." >&2
    fi
  fi

  chown -R coder:coder "$CLAUDE_CONFIG_HOME"
  echo "Claude Code config synced from repo." >&2
else
  echo "Warning: claude-config not mounted at $CLAUDE_CONFIG_REPO — skipping." >&2
fi

# Validate SSH keys are accessible
if [ -d /home/coder/.ssh ] && [ -n "$(ls -A /home/coder/.ssh 2>/dev/null)" ]; then
  echo "SSH keys detected at /home/coder/.ssh" >&2
else
  echo "Warning: No SSH keys found. ~/.ssh may not be mounted or is empty." >&2
  echo "  Git operations over SSH will not work." >&2
fi

# Persist Docker environment variables so they are available in code-server's
# integrated terminal.  Code-server spawns a new bash session that doesn't
# inherit PID 1's environment, so we write exports to a dedicated file and
# source it from ~/.bashrc.
ENV_FILE="/home/coder/.docker-env"
: > "$ENV_FILE"
for var in GITHUB_TOKEN GIT_USER_NAME GIT_USER_EMAIL \
           HOST_CODE_DIR HOST_HOME_DIR \
           ACQUIA_KEY ACQUIA_SECRET ACSF_API_KEY ACSF_USERNAME \
           OPENAI_KEY HOMEASSISTANT_WEBHOOK CLAUDE_STOP_WEBHOOK_URL \
           VAULT_ADDR VAULT_USER VAULT_PASS; do
  val="${!var:-}"
  if [ -n "$val" ]; then
    printf 'export %s=%q\n' "$var" "$val" >> "$ENV_FILE"
  fi
done
chown coder:coder "$ENV_FILE"
# Ensure ~/.bashrc sources the file (idempotent — only adds the line once)
BASHRC="/home/coder/.bashrc"
if ! grep -q '\.docker-env' "$BASHRC" 2>/dev/null; then
  printf '\n# Load Docker environment variables\n[ -f ~/.docker-env ] && . ~/.docker-env\n' >> "$BASHRC"
fi

# Drop to coder user and hand off to code-server (or whatever CMD is defined)
exec gosu coder "$@"
