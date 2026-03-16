# CLAUDE.md - Project Guide for anydev

## Project Overview

anydev is a portable, self-contained Docker-based development environment that provides browser-accessible VS Code (via code-server) with PHP 8.3, Node.js 22.x, and Python 3 pre-installed. It targets PHP/Drupal development on Windows WSL2 + Docker.

## Repository Structure

```
anydev/
├── CLAUDE.md                    # This file
├── README.md                    # Project overview and setup instructions
├── Dockerfile                   # Multi-layer image based on codercom/code-server
├── docker-compose.yml           # Service config (ports, volumes, env vars)
├── docker-compose.override.yml.example  # Optional mounts (e.g., Acquia credentials)
├── .env.example                 # Environment variable template (committed)
├── .dockerignore                # Build context filtering
├── entrypoint.sh                # Container startup script (git config, SSH validation)
├── lando-wrapper.sh             # Lando path-translation wrapper (see Lando section)
├── extensions.txt               # Declarative VS Code extension list
├── .gitignore                   # Ignores .env, docker-compose.override.yml, logs/
├── config/
│   └── settings.json            # VS Code settings (bind-mounted into container)
├── claude-config/               # Portable Claude Code customizations (tracked in repo)
│   ├── commands/                # Slash commands (symlinked into ~/.claude/commands/)
│   ├── agents/                  # Custom agent definitions (symlinked into ~/.claude/agents/)
│   ├── settings.json            # Base settings: hooks, plugins, model (no permissions)
│   └── default_mcp.json         # MCP server definitions
└── docs/
    ├── product_requirements.md  # Functional & non-functional requirements
    └── implementation_plan.md   # Detailed implementation specs, gotchas
```

## Key Architecture Decisions

- **Non-root container user:** `coder` at UID/GID matching host (default 1000)
- **Base image:** `codercom/code-server:latest` (Debian 12 / bookworm)
- **Extension management:** Build-time install from `extensions.txt` + named volume for persistence
- **SSH access:** Read-only `~/.ssh` bind-mount (no key material inside the container; passphrase prompts go through the mounted directory)
- **Settings:** `config/settings.json` bind-mounted, changes in VS Code write back to repo
- **Secrets via `.env`:** Gitignored; `.env.example` committed as template
- **Docker socket:** `/var/run/docker.sock` always mounted; `DOCKER_GID` build arg sets group membership so `coder` can use it without sudo
- **Lando interop:** Full Lando CLI available inside the container via `lando-wrapper.sh` (see below)
- **Claude Code:** Installed globally (`@anthropic-ai/claude-code`); `~/.claude` and `~/.claude.json` bind-mounted from host for credential passthrough; portable customizations in `claude-config/` (see below)

## Lando Integration

Lando CLI is installed in the container as `@lando/core` (npm). A path-translation wrapper (`lando-wrapper.sh`) sits in front of the real binary at `/usr/local/bin/lando.real`.

**The path problem:** Lando registers project roots at host paths (e.g., `/home/ian/code/myproject`). Inside the container, the `coder` user's home is `/home/coder`, so those same files are at `/home/coder/code/myproject`. Without translation, two things break:
1. Lando can't match the CWD to its project registry (wrong prefix)
2. Lando calls `os.homedir()` to find `~/.lando` and to write Docker Compose bind-mount paths. Inside the container that returns `/home/coder/...`, but Docker daemon runs on the host where `/home/coder/...` doesn't exist — causing "is a directory" OCI errors when starting containers.

**The solution (two parts):**

*Part 1 — Home directory symlink:* `entrypoint.sh` runs as root, reads `HOST_HOME_DIR` (e.g. `/home/ian`), and creates a symlink `${HOST_HOME_DIR} → /home/coder` inside the container. It also exports `HOME=${HOST_HOME_DIR}` before dropping to the `coder` user via `gosu`. This makes `os.homedir()` return the host path, so all generated Docker Compose files use valid host-side paths.

*Part 2 — CWD translation:* `lando-wrapper.sh` translates the CWD from `/home/coder/code/*` to `$HOST_CODE_DIR/*` before calling `lando.real`, so Lando finds the correct project in its registry.

Supporting requirements in `docker-compose.yml`:
1. `~/.lando:/home/coder/.lando` — shares the host's Lando config, cache, and certificates
2. `${HOST_CODE_DIR}:${HOST_CODE_DIR}` — mounts the code dir at its host path so translated CWD paths resolve inside the container
3. `HOST_CODE_DIR` env var — used by the wrapper for CWD translation
4. `HOST_HOME_DIR` env var — used by the entrypoint for the home symlink and `HOME` override

## Claude Code Customizations

The `claude-config/` directory holds portable Claude Code configuration that travels with the repo. At container startup, `entrypoint.sh` syncs these into `~/.claude/`:

- **`commands/`** and **`agents/`** — symlinked into `~/.claude/commands/` and `~/.claude/agents/`. Because they're symlinks, edits inside the container write back to the repo directory (and are visible via `git diff`).
- **`default_mcp.json`** — symlinked into `~/.claude/default_mcp.json`.
- **`settings.json`** — merged into `~/.claude/settings.json`. The repo version provides hooks, model, and plugin config. The `permissions` block from the existing `~/.claude/settings.json` is preserved (these are machine-specific path grants that accumulate as you approve tool use).

**Adding a new command or agent:** Create the file in `claude-config/commands/` or `claude-config/agents/`, commit, and it will be available on any machine running this container.

**Changing hooks or plugins:** Edit `claude-config/settings.json`. The change applies on next container restart.

**Machine-specific overrides:** `~/.claude/settings.local.json` is never touched by the merge and remains local. Use it for per-machine MCP servers or permissions.

## Installed Tools (beyond the base image)

| Tool | Install method | Available as |
|------|---------------|--------------|
| PHP 8.3 + extensions | apt (Ondrej Sury Debian repo) | `php`, `php8.3` |
| Composer | Official installer | `composer` |
| Node.js 22 LTS | NodeSource apt repo | `node`, `npm` |
| yarn | `npm install -g` | `yarn` |
| Python 3 + pip | apt | `python3`, `pip3` |
| GitHub CLI | Official apt repo | `gh` |
| Docker CLI | Official Docker apt repo | `docker` |
| Drush Launcher | phar download | `drush` |
| Lando CLI | `npm install -g @lando/core` | `lando` (via wrapper) |
| Claude Code | `npm install -g @anthropic-ai/claude-code` | `claude` |

## Build & Run

```sh
cp .env.example .env             # Fill in your values
docker compose build             # Build the image
docker compose up -d             # Start in background
docker compose down              # Stop
```

Build args: `USER_UID`, `USER_GID`, `DOCKER_GID`, `PHP_VERSION` (default 8.3), `NODE_MAJOR` (default 22), `LANDO_VERSION` (default 3.26.2)

## Important Gotchas

1. Extensions must be installed as `coder` user, not root
2. Pre-create parent directory before bind-mounting `settings.json`
3. `HOST_CODE_DIR` must be set correctly — the Lando wrapper depends on it for path translation
4. UID mismatch between host and container causes file permission issues
5. Named volume can shadow rebuilt extensions — delete volume to refresh
6. Base image is Debian (bookworm), not Ubuntu — use correct PHP PPA (Ondrej Sury)
7. Composer global packages installed as root won't appear on coder's PATH
8. Use `docker compose` (space, plugin form), not legacy `docker-compose`
9. `DOCKER_GID` must match the host Docker socket GID (`stat -c '%g' /var/run/docker.sock`)

## Development Conventions

- Default branch: `master`
- No CI pipeline configured
- No test suite — this is a container configuration project
- Keep secrets out of the image and repo; use `.env` for all credentials
