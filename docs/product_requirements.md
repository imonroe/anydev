# Portable Developer Environment — Spec & Product Requirements

## Overview

The goal is to create a self-contained, portable development environment running inside a Docker container that can be spun up identically on any machine capable of running Docker. The environment will use [Code Server](https://github.com/coder/code-server) to provide a browser-accessible VS Code interface, with the developer's local codebase mounted as a volume. This eliminates per-machine setup time and guarantees consistent tooling, extensions, and environment variables across all workstations.

Primary development targets are **PHP**, **JavaScript**, and **Python**, with a heavy focus on **Drupal** CMS development. Local application stacks will continue to be managed by **Lando**, which runs its own Docker containers independently on the host machine.

---

## Goals

- Spin up a full VS Code development environment on any machine with WSL2 + Docker in under 5 minutes
- Maintain consistent versions of PHP, Node.js, Python, Composer, and related global tooling
- Maintain consistent VS Code extensions and settings across all machines
- Preserve the existing Lando-based workflow for running Drupal application stacks
- Support SSH/git workflows from inside the container
- Store all code on the host filesystem (not inside the container) to ensure data persistence

---

## Non-Goals

- Replacing Lando as the application server environment
- Running production workloads in this container
- Supporting Windows-native Docker (WSL2 Docker is the assumed runtime)
- Full offline operation (initial image pull requires internet access)

---

## System Architecture
```
Host Machine (Windows + WSL2)
├── Docker Engine (running inside WSL2)
│   ├── [code-server container]  ← This project
│   │   ├── Code Server (VS Code in browser)
│   │   ├── PHP + Composer
│   │   ├── Node.js + npm/yarn
│   │   ├── Python + pip
│   │   └── Volume: ~/code (host) → /home/coder/code (container)
│   │
│   └── [Lando containers]  ← Existing workflow, unchanged
│       ├── nginx/apache
│       ├── php-fpm
│       ├── mysql/postgres
│       └── etc.
│
└── ~/code/  (WSL2 filesystem — source of truth for all code)
```

The Code Server container and Lando containers are **sibling containers** managed by separate Compose configurations. They share the host Docker daemon but operate on different networks by default.

---

## Requirements

### Functional Requirements

| ID | Requirement |
|----|-------------|
| F-01 | Code Server must be accessible via browser on a configurable local port |
| F-02 | The container must have PHP (8.2+), Composer, Node.js (LTS), npm, yarn, Python 3, and pip installed |
| F-03 | Global Drupal tooling must be available: Drush launcher, Drupal Console (where applicable) |
| F-04 | The host `~/code` directory must be mounted read/write into the container |
| F-05 | VS Code extensions must be declaratively defined and auto-installed on container start |
| F-06 | Environment variables (API keys, tokens, etc.) must be injectable via `.env` file, not hardcoded in the image |
| F-07 | SSH agent forwarding must work inside the container for git operations |
| F-08 | Git must be configured with host identity (name, email) via environment variables |
| F-09 | The container must run as a non-root user with a UID/GID matching the WSL2 host user |
| F-10 | The setup must be fully reproducible from a single `docker compose up` command |

### Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| N-01 | Image build time should be under 10 minutes on a standard broadband connection |
| N-02 | Image size should be kept reasonable (target under 3GB compressed) |
| N-03 | The container should start in under 30 seconds after image is pulled |
| N-04 | The Dockerfile must use layer ordering and caching to minimize rebuild time during iteration |
| N-05 | Secrets must never be baked into the image |

---

## Key Challenges and Approaches

### 1. File Permission Mismatches (UID/GID)

**Problem:** When a Docker container writes files to a volume-mounted host directory, it uses the UID/GID of the user running inside the container. If that doesn't match the WSL2 host user (typically UID 1000), files created inside the container will be owned by the wrong user on the host. This causes issues with Lando (which also mounts the same `~/code` directory), git operations, and general file editing.

**Approaches:**

- **Preferred:** Build the image with a `coder` user at a fixed UID/GID (e.g., 1000:1000), matching the default WSL2 user. Use `--build-arg` to make this configurable for non-standard setups.
- **Alternative:** Use the `--user` flag in `docker-compose.yml` to pass the host UID/GID at runtime via `$(id -u):$(id -g)`.
- **Avoid:** Running the container as root to sidestep the issue — this creates security problems and can still produce ownership conflicts.

**Resolution approach:** Parameterize UID/GID in the Dockerfile with build args defaulting to `1000:1000`. Document how to override in the README for users with different UIDs.

---

### 2. Lando Interoperability

**Problem:** Lando manages its own Docker network and containers. The Code Server container lives on a different Docker network by default. This means that from inside the Code Server container terminal, commands like `lando drush cr` will not work — `lando` CLI is not installed inside the container, and even if it were, it communicates with the host Docker socket in ways that require careful privilege configuration.

**Approaches:**

- **Option A — Host terminal for Lando (default):** Keep a separate WSL2 terminal on the host for all `lando` commands. Use the Code Server terminal only for non-Lando tasks (git, npm, Composer, etc.). Simple and reliable, but splits workflow across two terminals.
- **Option B — Mount the Docker socket (advanced):** Mount `/var/run/docker.sock` into the Code Server container and install the Lando CLI inside it. This allows running `lando` commands from the Code Server terminal. Security trade-off: socket access grants the container significant host privileges.
- **Option C — Join Lando's Docker network:** Configure the Code Server container to join Lando's Docker network using `external: true` network references in Compose. This allows the Code Server container to reach Lando's PHP container directly for Drush operations without needing Lando CLI.
- **Option D — Expose Lando services on fixed localhost ports:** Configure Lando to bind services to fixed localhost ports and access them from the Code Server container via `host.docker.internal`. Less elegant but straightforward.

**Resolution approach:** Default to Option A for simplicity and security. Document Option B as an opt-in advanced configuration.

---

### 3. SSH Key and Git Credential Access

**Problem:** SSH keys live on the host. The container needs access to them for git operations (cloning repos, pushing to GitHub/GitLab, etc.). Simply bind-mounting `~/.ssh` works but introduces risk if the container is ever compromised.

**Approaches:**

- **Preferred — SSH agent forwarding:** Forward the host's SSH agent socket into the container using `SSH_AUTH_SOCK`. The container gets authenticated access to keys without the keys themselves being present inside it. Requires the host SSH agent to be running (standard in WSL2 with `ssh-agent` or `keychain`).
- **Alternative — Read-only `.ssh` mount:** Bind-mount `~/.ssh` as read-only into the container. Simpler, but copies key material into the container's accessible filesystem.
- **For HTTPS git:** Use a Git credential helper by mounting the host's git config and credential store, or store a Personal Access Token in the `.env` file.

**Resolution approach:** Default to SSH agent forwarding via `SSH_AUTH_SOCK` socket mount. Document `.ssh` bind-mount as fallback.

---

### 4. VS Code Extension Management

**Problem:** Code Server extensions are installed into a path inside the container. If the container is rebuilt or replaced, extensions are lost unless they are explicitly re-installed. Manually listing and re-installing extensions after every rebuild is friction.

**Approaches:**

- **Option A — Install at build time:** Add a `RUN` step in the Dockerfile that calls `code-server --install-extension <id>` for each desired extension. Extensions are baked into the image. Rebuild required to add/remove extensions.
- **Option B — Persist extensions via named volume:** Mount a named Docker volume at the extensions directory (`~/.local/share/code-server/extensions`). Extensions installed interactively persist across container restarts. Risk of drift from the declared list.
- **Option C — Install at startup via entrypoint script:** Maintain an `extensions.txt` file listing extension IDs. An entrypoint script installs missing extensions on each container start. Slower startup but always in sync with the declared list.

**Resolution approach:** Hybrid — bake a core/essential extension list into the Dockerfile (Option A) and use a named volume (Option B) so that extensions added interactively also persist. Document `extensions.txt` as the authoritative source for rebuilds.

---

### 5. Environment Variable and Secrets Management

**Problem:** Development workflows involve secrets: API keys, Pantheon/Acquia tokens, database credentials, etc. These must be accessible inside the container but must never be committed to the image or the repo.

**Approaches:**

- **`.env` file at compose root (default):** Docker Compose natively reads a `.env` file and makes variables available to the container. The `.env` file is gitignored. A `.env.example` is committed to document required variables.
- **Host environment passthrough:** Use `environment:` in `docker-compose.yml` to pass specific host environment variables into the container (e.g., `- PANTHEON_TOKEN`). Requires variables to be set in the host shell/profile.
- **Secrets managers (out of scope):** Tools like Doppler or 1Password CLI can inject secrets at runtime. Worth noting for future team use.

**Resolution approach:** `.env` file approach as the default, with `.env.example` committed. Document host passthrough as an alternative.

---

### 6. Image Size and Rebuild Performance

**Problem:** Installing PHP, Node.js, Python, Composer, and a full set of global tools in one image will produce a large image. Frequent rebuilds slow down iteration.

**Approaches:**

- Order Dockerfile `RUN` commands from least-to-most-frequently-changed to maximize layer cache hits
- Use a well-maintained base image (e.g., `codercom/code-server` official image) rather than building from scratch
- Keep global tool installs minimal — prefer project-level tooling (managed by Lando or local package managers) over baking everything into the image
- Use `.dockerignore` to keep the build context lean

**Resolution approach:** Start from the official `codercom/code-server` base image. Layer PHP, Node.js, and Python installs on top using official package sources (e.g., `ondrej/php` PPA, NodeSource). Keep baked-in globals to a minimum.

---

## Proposed File Structure
```
portable-devenv/
├── Dockerfile
├── docker-compose.yml
├── docker-compose.override.yml.example   # optional local overrides
├── .env.example                          # documents required env vars
├── .gitignore                            # ignores .env, any secrets
├── entrypoint.sh                         # startup script (extension installs, etc.)
├── extensions.txt                        # declarative list of VS Code extension IDs
├── config/
│   └── settings.json                     # Code Server / VS Code settings
└── README.md
```

---

## Configuration Reference

### Environment Variables (`.env`)

| Variable | Description | Example |
|----------|-------------|---------|
| `CODE_SERVER_PORT` | Host port for Code Server UI | `8080` |
| `CODE_SERVER_PASSWORD` | Password for Code Server web UI | `changeme` |
| `HOST_CODE_DIR` | Absolute path to code directory on host | `/home/ian/code` |
| `USER_UID` | UID to run container as | `1000` |
| `USER_GID` | GID to run container as | `1000` |
| `GIT_USER_NAME` | Git commit author name | `Ian Monroe` |
| `GIT_USER_EMAIL` | Git commit author email | `ian@example.com` |

Sensitive variables (API keys, hosting tokens, etc.) should be added per-developer in `.env` and documented but not valued in `.env.example`.

---

## Open Questions

1. **Drush access pattern:** Should the default setup support running Drush from within Code Server (via Docker socket or network bridging), or is a host terminal for Lando commands acceptable as the baseline?
2. **PHP version flexibility:** Should the image support multiple PHP versions (e.g., via `update-alternatives`), or pin to a single version and rebuild to switch?
3. **Node version management:** Is a version manager (`nvm`, `fnm`) worth including for projects requiring different Node versions, or is a single LTS version sufficient?
4. **Persistence strategy for Code Server settings:** Should `settings.json` be volume-mounted from the repo (always in sync with git) or managed inside a named volume (editable in the UI)?
5. **Multi-machine sync:** Is there a need to sync `.env` or the extensions list across machines (e.g., via a private dotfiles repo), or is manual copy acceptable?

---

## Success Criteria

- [ ] `docker compose up` on a fresh WSL2 + Docker machine produces a working Code Server instance in under 5 minutes
- [ ] All listed language runtimes (PHP, Node.js, Python) are available in the Code Server terminal
- [ ] VS Code extensions defined in `extensions.txt` are present without manual installation
- [ ] Files created inside the container are owned by the correct host user
- [ ] Git push/pull via SSH works from the Code Server terminal
- [ ] Lando continues to function normally on the host alongside the running container
- [ ] No secrets are present in the Docker image or committed to the repo

