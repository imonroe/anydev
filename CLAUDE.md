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
├── docker-compose.override.yml.example  # Optional Docker socket access
├── .env.example                 # Environment variable template (committed)
├── .dockerignore                # Build context filtering
├── entrypoint.sh                # Container startup script (git config, SSH validation)
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
- **Base image:** `codercom/code-server:latest` (Debian-based)
- **Extension management:** Build-time install from `extensions.txt` + named volume for persistence
- **SSH agent forwarding:** Socket mount (no private key exposure)
- **Settings:** `config/settings.json` bind-mounted, changes in VS Code write back to repo
- **Secrets via `.env`:** Gitignored; `.env.example` committed as template
- **Lando interop:** Sibling containers; Lando commands in host terminal (Docker socket opt-in)

## Build & Run

```sh
cp .env.example .env             # Fill in your values
docker compose build             # Build the image
docker compose up -d             # Start in background
docker compose down              # Stop
```

Build args: `USER_UID`, `USER_GID`, `PHP_VERSION` (default 8.3), `NODE_MAJOR` (default 22)

## Important Gotchas

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
- No CI pipeline configured
- No test suite — this is a container configuration project
- Keep secrets out of the image and repo; use `.env` for all credentials
