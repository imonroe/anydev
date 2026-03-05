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
- **Claude Code:** Installed globally (`@anthropic-ai/claude-code`); `~/.claude` and `~/.claude.json` bind-mounted from host for credential passthrough

## Lando Integration

Lando CLI is installed in the container as `@lando/core` (npm). A path-translation wrapper (`lando-wrapper.sh`) sits in front of the real binary at `/usr/local/bin/lando.real`.

**The path problem:** Lando registers project roots at host paths (e.g., `/home/ian/code/myproject`). Inside the container, those same files are at `/home/coder/code/myproject`. Without translation, Lando can't match the CWD to its project registry, and `lando start` would create containers with incorrect volume mount paths.

**The solution:** `lando-wrapper.sh` translates the CWD from `/home/coder/code/*` to `$HOST_CODE_DIR/*` before calling `lando.real`. Two supporting requirements in `docker-compose.yml`:
1. `~/.lando:/home/coder/.lando` — shares the host's Lando config, cache, and certificates
2. `${HOST_CODE_DIR}:${HOST_CODE_DIR}` — mounts the code dir at its host path so translated paths resolve inside the container
3. `HOST_CODE_DIR` is passed as an env var so the wrapper knows the host-side path

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
