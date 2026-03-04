# CLAUDE.md - Project Guide for anydev

## Project Overview

anydev is a portable, self-contained Docker-based development environment that provides browser-accessible VS Code (via code-server) with PHP 8.3, Node.js 22.x, and Python 3 pre-installed. It targets PHP/Drupal development on Windows WSL2 + Docker.

**Status:** Pre-implementation — detailed specs exist in `docs/`, but no implementation files (Dockerfile, docker-compose.yml, etc.) have been created yet.

## Repository Structure

```
anydev/
├── CLAUDE.md                    # This file
├── README.md                    # Project overview and setup instructions
├── .gitignore                   # Ignores: logs/
└── docs/
    ├── product_requirements.md  # Functional & non-functional requirements (F-01–F-10, N-01–N-05)
    └── implementation_plan.md   # Detailed implementation specs, Dockerfile layers, gotchas
```

## Planned Implementation Files (not yet created)

- `Dockerfile` — Multi-layer image based on `codercom/code-server:latest`
- `docker-compose.yml` — Service config (ports, volumes, env vars, networks)
- `docker-compose.override.yml.example` — Optional local overrides
- `.env.example` — Environment variable template (committed)
- `.env` — Actual env vars (gitignored, per-developer)
- `.dockerignore` — Build context filtering
- `entrypoint.sh` — Container startup script (git config, signal handling)
- `extensions.txt` — Declarative VS Code extension list
- `config/settings.json` — VS Code settings (bind-mounted into container)

## Key Architecture Decisions

- **Non-root container user:** `coder` at UID/GID 1000 matching WSL2 defaults
- **Sibling containers:** Code Server and Lando operate independently
- **Extension management:** Build-time install from `extensions.txt` + named volume for persistence
- **SSH agent forwarding:** Socket mount (no private key exposure)
- **Secrets via `.env`:** Gitignored; `.env.example` committed as template

## Build & Run (once implemented)

```sh
docker compose build          # Build the image
docker compose up -d          # Start in background
docker compose down           # Stop
```

Build args: `USER_UID`, `USER_GID`, `PHP_VERSION`, `NODE_MAJOR`

## Important Gotchas (from docs/implementation_plan.md)

1. Extensions must be installed as `coder` user, not root
2. Pre-create parent directory before bind-mounting `settings.json`
3. `SSH_AUTH_SOCK` must be set in `.env` or compose syntax breaks
4. UID mismatch between host and container causes file permission issues
5. Named volume can shadow rebuilt extensions — delete volume to refresh
6. Base image is Debian, not Ubuntu — use correct PHP PPA (Ondrej Sury)
7. Composer global packages installed as root won't appear on coder's PATH
8. Use `docker compose` (space, plugin form), not legacy `docker-compose`

## Development Conventions

- Default branch: `master`
- No CI pipeline configured yet
- No test suite — this is a container configuration project
- Keep secrets out of the image and repo; use `.env` for all credentials
