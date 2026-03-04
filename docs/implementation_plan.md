# Implementation Plan: Portable Developer Environment

## Document Purpose

This document translates the PRD decisions and open questions into a concrete, step-by-step implementation guide. It resolves all open questions, defines every file to be created, explains Dockerfile layer ordering, and calls out tricky implementation details and gotchas.

---

## Resolved Open Questions

### 1. Drush Access Pattern
**Decision:** Host terminal for Lando commands (Option A) is the baseline. No Drush integration inside the container for MVP.

**Justification:** Mounting the Docker socket (Option B) grants the container root-equivalent access to the host Docker daemon — a meaningful security trade-off that should not be the default. The workflow split (Lando commands in a WSL2 terminal, code editing and git in Code Server) is a clean boundary. Option B is documented in `docker-compose.override.yml.example` with a clear security warning.

---

### 2. PHP Version Flexibility
**Decision:** Pin to PHP 8.3 as the single version. No `update-alternatives` multi-version support for MVP.

**Justification:** Drupal 10/11 require PHP 8.1+, and teams typically pin to one version per project. The Lando stack (not this container) runs PHP for the application — this container's PHP is primarily for Composer, linting, and static analysis. A single pinned version simplifies the image. Switching PHP versions requires a rebuild, which is acceptable. Expose a `PHP_VERSION` build arg to make the pin visible and easy to change.

---

### 3. Node Version Management
**Decision:** Install a single LTS Node.js version (Node 22 LTS) via NodeSource. No `nvm` or `fnm` for MVP.

**Justification:** `nvm`/`fnm` require shell initialization that interacts poorly with Code Server's integrated terminal in non-login shell environments. For Drupal-focused work, Node is primarily used for theme compilation and most tooling tracks LTS without issue. Expose a `NODE_MAJOR` build arg to make the version easy to change.

---

### 4. settings.json Persistence
**Decision:** Bind-mount `config/settings.json` from the repository into the container.

**Justification:** The goal is a consistent, reproducible environment. A named volume for settings can drift from the committed repo state. Bind-mounting keeps settings in git — changes through the VS Code UI write back to the repo file, which is the desired behavior. This also aligns with the "gitignored .env + committed config" mental model.

> **Note:** The bind-mount target inside the container must be `~/.local/share/code-server/User/settings.json`. The parent directory must be pre-created in the Dockerfile.

---

### 5. Multi-Machine Sync
**Decision:** Out of scope for MVP. Manual copy of `.env` from `.env.example` is the baseline setup on each new machine.

**Justification:** Sync of secrets adds infrastructure and security surface area. For a single developer, the one-time setup friction is acceptable. Teams wanting sync should look at private dotfiles repos for non-secret config and a tool like Doppler or 1Password CLI for secrets — post-MVP concerns.

---

## Implementation Phases

### Phase 1 — Minimal Bootable Container
**Goal:** Get Code Server running in a container with correct UID/GID and the code directory mounted. No extra tooling yet.

**Success test:** Navigate to `http://localhost:${CODE_SERVER_PORT}` and see the Code Server login screen. Open a terminal in Code Server and confirm you are running as the `coder` user, not root. Confirm `/home/coder/code` shows the host `~/code` directory contents.

**Files created in this phase:**
- `.env.example`
- `.env` (local, gitignored)
- `.gitignore`
- `.dockerignore`
- `Dockerfile` (base only — FROM, USER/UID setup, WORKDIR)
- `docker-compose.yml`
- `README.md` (stub)

---

### Phase 2 — Language Runtimes and Global Tooling
**Goal:** Install PHP 8.3 + Composer, Node.js LTS + npm + yarn, and Python 3 + pip inside the image.

**Success test:** Open a Code Server terminal. Run `php --version`, `composer --version`, `node --version`, `npm --version`, `yarn --version`, `python3 --version`, `pip3 --version`. All commands resolve to expected versions.

**Files modified in this phase:**
- `Dockerfile` (add runtime install layers)

---

### Phase 3 — SSH Agent Forwarding and Git Configuration
**Goal:** SSH agent socket is forwarded into the container. Git is configured with the identity from `.env`. `git push` works from the Code Server terminal.

**Success test:** With SSH agent running on the host and keys loaded, open a Code Server terminal and run `ssh -T git@github.com`. Confirm successful authentication. Run `git config --global user.name` and confirm it matches `GIT_USER_NAME` in `.env`.

**Files created or modified in this phase:**
- `entrypoint.sh` (new — handles git config and execs code-server)
- `docker-compose.yml` (add SSH socket mount and git environment variables)
- `Dockerfile` (COPY entrypoint.sh, set ENTRYPOINT)

---

### Phase 4 — Extensions and Settings
**Goal:** Core extensions are baked into the image. A named volume persists interactively-added extensions. `settings.json` is bind-mounted from the repo.

**Success test:** Start the container fresh (no prior named volume). Open Code Server and confirm all extensions in `extensions.txt` are installed without manual action. Modify a setting through the VS Code UI and confirm the change is visible in `config/settings.json` on the host. Stop and restart the container; confirm interactively-added extensions are still present.

**Files created or modified in this phase:**
- `extensions.txt` (new)
- `config/settings.json` (new)
- `Dockerfile` (add extension install RUN step)
- `docker-compose.yml` (add named volume for extensions, bind-mount for settings.json)

---

### Phase 5 — Override File, Cleanup, and Documentation
**Goal:** Document the Docker socket advanced option, finalize the README with full setup instructions, and add the override example file.

**Success test:** Follow the README setup instructions on a clean machine from scratch. The environment is running within 5 minutes.

**Files created or modified in this phase:**
- `docker-compose.override.yml.example` (new)
- `README.md` (completed)

---

## File-by-File Specification

### `Dockerfile`

The most critical file. Every layer ordering decision has cache implications.

**Layer order and rationale:**

1. `FROM codercom/code-server:<version>` — The base provides Debian (bookworm), the `coder` user at UID 1000, and a working `code-server` binary. **Pin to a specific version tag** (not `latest`) for reproducibility. `latest` is acceptable during initial development.

2. `ARG USER_UID=1000` / `ARG USER_GID=1000` / `ARG PHP_VERSION=8.3` / `ARG NODE_MAJOR=22` — Declare all build args immediately after FROM so they are available throughout the build. These are build args, not ENV vars — they are only needed during the build.

3. `USER root` — The base image drops to `coder` at the end of its own Dockerfile. Switch back to root to install system packages.

4. `RUN` — **UID/GID adjustment.** Modify the existing `coder` user and group to match the `USER_UID`/`USER_GID` build args using `usermod` and `groupmod`. Then `chown -R` the home directory. Do this first, before installing anything, so all subsequent ownership is correct. See Tricky Details for the specifics.

5. `RUN` — **System prerequisites.** Install `curl`, `git`, `gnupg`, `lsb-release`, `ca-certificates`, and anything needed to add third-party package repositories. This layer changes infrequently — near the top for maximum cache reuse.

6. `RUN` — **Add PHP repository.** Add the Ondrej Sury Debian PHP repository (note: Debian variant, not Ubuntu — see Gotcha 6). Separate from the install step so that changing the package list below gets a cache hit on the repo-add step.

7. `RUN` — **Install PHP + extensions.** Install `php${PHP_VERSION}-cli` and the following extensions: `mbstring`, `xml`, `curl`, `zip`, `gd`, `intl`, `mysql`, `pgsql`, `sqlite3`, `bcmath`. Add `xdebug` if local debugging is desired. End with `rm -rf /var/lib/apt/lists/*` to clean the apt cache in the same layer.

8. `RUN` — **Install Composer.** Use the official installer: download `composer-setup.php`, verify the checksum against the published hash, run the installer with `--install-dir=/usr/local/bin --filename=composer`, remove the installer. Do not use the apt package — it lags behind.

9. `RUN` — **Add NodeSource repository.** Use the official NodeSource setup script for `NODE_MAJOR`. Separate layer for the same cache reason as PHP.

10. `RUN` — **Install Node.js, npm, yarn.** `apt-get install nodejs` after NodeSource is active. Install yarn via `npm install -g yarn` (the apt package is outdated). Clean apt cache.

11. `RUN` — **Install Python 3 and pip.** Python 3 is often pre-installed on Debian-based images; explicitly install `python3-pip` and `python3-venv`. Clean apt cache.

12. `RUN` — **Install global Drupal tooling.** Install Drush Launcher as a global tool. The correct approach is to download the drush launcher phar to `/usr/local/bin/drush` and `chmod +x` it — this puts it on PATH for all users without Composer global install complications. See Gotcha 7 for why `composer global require` as root is problematic.

13. `USER coder` — Switch to the `coder` user before installing extensions, so they land in `coder`'s home directory. **This switch must happen before the extension install step.** See Gotcha 1.

14. `RUN mkdir -p /home/coder/.local/share/code-server/User` — Pre-create the settings directory as the `coder` user. This prevents Docker from creating a directory named `settings.json` when the bind-mount is applied. See Gotcha 2.

15. `COPY extensions.txt /home/coder/extensions.txt` — Copy the extensions list. Placed after system installs (which change rarely) and as the `coder` user (for correct ownership).

16. `RUN` — **Install core VS Code extensions.** Iterate over `extensions.txt` and call `code-server --install-extension <id>` for each. Must run as `coder`. Extensions install to `/home/coder/.local/share/code-server/extensions/`.

17. `COPY --chown=coder:coder entrypoint.sh /usr/local/bin/entrypoint.sh` — Copy and set executable. The `--chown` flag avoids a separate layer.
    `RUN chmod +x /usr/local/bin/entrypoint.sh`

18. `WORKDIR /home/coder/code` — Set the default working directory to the mounted code volume so new terminals open there.

19. `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]` — Override the base image's entrypoint with our script. The script is responsible for eventually calling code-server. See Tricky Details on `exec "$@"`.

---

### `docker-compose.yml`

**Key configuration items:**

- `build.context: .` and `build.args` block — pass `USER_UID` and `USER_GID` from `.env` to the build process. This links build-time UID/GID to the runtime values.

- `ports` — map `${CODE_SERVER_PORT}:8080`. Code Server listens on 8080 inside the container by default.

- `environment` block:
  - `PASSWORD=${CODE_SERVER_PASSWORD}` — the specific env var name code-server reads for auth
  - `GIT_USER_NAME`
  - `GIT_USER_EMAIL`
  - `SSH_AUTH_SOCK=${SSH_AUTH_SOCK}` — see SSH details below

- `volumes` block — three entries:
  1. `${HOST_CODE_DIR}:/home/coder/code` — host code directory, read-write
  2. `code-server-extensions:/home/coder/.local/share/code-server/extensions` — named volume for extension persistence
  3. `./config/settings.json:/home/coder/.local/share/code-server/User/settings.json` — bind-mount, read-write (so UI edits flow back to the repo file)
  4. `${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}` — SSH agent socket, same path inside and outside

- `volumes` top-level — declare: `code-server-extensions: {}`

- `restart: unless-stopped` — useful for a dev tool that should survive reboots.

---

### `docker-compose.override.yml.example`

Documents optional configurations that users can activate by copying to `docker-compose.override.yml` (gitignored).

**Content:**
- Docker socket mount example (Option B for Lando): how to mount `/var/run/docker.sock:/var/run/docker.sock` with a security warning and a note that Lando CLI would also need to be installed inside the container.
- Clear comment that this file is an example and `docker-compose.override.yml` must never be committed.

---

### `.env.example`

Committed to the repo. Documents every variable with example values for non-secret vars and blank/placeholder values for secrets.

**Variables:**
```
CODE_SERVER_PORT=8080
CODE_SERVER_PASSWORD=          # Required. Set a strong password.
HOST_CODE_DIR=/home/your-username/code
USER_UID=1000                  # Match output of: id -u
USER_GID=1000                  # Match output of: id -g
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=you@example.com
SSH_AUTH_SOCK=                 # Set to output of: echo $SSH_AUTH_SOCK
```

Add explanatory comments above each variable describing what it does and how to find the correct value.

---

### `.gitignore`

**Must include:**
- `.env`
- `docker-compose.override.yml`
- OS files (`.DS_Store`, `Thumbs.db`)

**Must NOT include:**
- `.env.example`
- `config/settings.json`
- `extensions.txt`

---

### `.dockerignore`

Prevents unnecessary files from being sent to the Docker build daemon.

**Include:**
- `.env`
- `.git/`
- `docker-compose.override.yml`
- `logs/`
- `README.md`
- `docs/`
- Any editor config files

The build context only needs: `Dockerfile`, `entrypoint.sh`, `extensions.txt`, `config/settings.json`.

---

### `entrypoint.sh`

Runs every time the container starts. Must be minimal and fast.

**Responsibilities in order:**

1. `set -euo pipefail` — strict mode so any error is immediately visible.

2. **Configure git global identity** from environment variables:
   ```sh
   git config --global user.name "${GIT_USER_NAME:-}"
   git config --global user.email "${GIT_USER_EMAIL:-}"
   ```
   Use `${VAR:-}` (default-to-empty) rather than `${VAR}` so `set -u` doesn't fail when the variable is unset. Emit a warning if either is empty.

3. **Validate SSH socket (optional but helpful):** If `SSH_AUTH_SOCK` is set but the socket file does not exist, emit a warning. Do not exit — code-server should start regardless. This helps debug the most common SSH forwarding failure mode (socket path changed after a reboot).

4. `exec "$@"` — **Critical.** Replaces the shell process with the code-server command so signals (SIGTERM, SIGINT) pass through correctly. Without `exec`, `docker stop` must wait for the full timeout before forcefully killing the container.

**What the script must NOT do:**
- Install extensions (done at build time — do not slow down every startup)
- Run as root (the user is `coder` by the time Docker calls ENTRYPOINT)
- Hardcode any values that belong in environment variables

---

### `extensions.txt`

One extension ID per line, in `publisher.extension-name` format. This is the authoritative list for rebuilds.

**Recommended initial contents:**
```
bmewburn.vscode-intelephense-client    # PHP IntelliSense
xdebug.php-debug                       # Xdebug integration
esbenp.prettier-vscode                 # Prettier formatter
dbaeumer.vscode-eslint                 # ESLint
ms-python.python                       # Python language support
redhat.vscode-yaml                     # YAML (heavily used in Drupal config)
eamodio.gitlens                        # Git history visualization
EditorConfig.EditorConfig              # .editorconfig support (Drupal standards)
streetsidesoftware.code-spell-checker  # Spell checking
```

Keep this list conservative. Extensions increase image size and build time. Project-specific extensions should be added interactively (they persist via the named volume).

---

### `config/settings.json`

Standard VS Code `settings.json`. Committed to the repo, bind-mounted into the container.

**Settings to include:**
- `"editor.formatOnSave": true`
- `"editor.tabSize": 2` (Drupal uses 2 spaces)
- `"editor.insertSpaces": true`
- `"files.trimTrailingWhitespace": true`
- `"files.insertFinalNewline": true`
- `"php.validate.executablePath": "/usr/bin/php"`
- `"terminal.integrated.defaultProfile.linux": "bash"`
- `"git.autofetch": false` (disable to avoid background SSH agent prompts)

Do not add extension-specific settings for extensions not in `extensions.txt`. Keep it generic enough to work out of the box.

---

### `README.md`

The onboarding document. A developer on a new machine should be able to follow it top-to-bottom with no external knowledge.

**Sections:**

1. **Prerequisites** — WSL2, Docker (WSL2 backend), SSH agent with keys loaded
2. **First-Time Setup** — clone, copy `.env.example` → `.env`, fill in values, `docker compose build`, `docker compose up -d`, open browser
3. **SSH Agent Setup** — explain that `SSH_AUTH_SOCK` must be set in `.env` to the output of `echo $SSH_AUTH_SOCK`; note the path changes after reboots/agent restarts
4. **Daily Usage** — `docker compose up -d` / `docker compose down`, URL
5. **Lando Workflow** — Lando commands run in a separate WSL2 terminal on the host; Code Server terminal is for git, Composer, npm, Python
6. **Adding Extensions** — hybrid model explained; add to `extensions.txt` + rebuild for permanent additions, or install interactively for session-persistent additions
7. **Rebuilding the Image** — `docker compose down`, optionally `docker volume rm <project>_code-server-extensions` (required if extensions changed), `docker compose build`, `docker compose up -d`
8. **Changing PHP/Node Versions** — explain the build args
9. **Advanced: Docker Socket Access** — document the override file approach with security warning
10. **Troubleshooting** — common failure modes from the Gotchas section below

---

## Tricky Implementation Details

### How codercom/code-server Handles the coder User

The official `codercom/code-server` image creates a `coder` user at UID 1000 and sets `USER coder` at the end of its Dockerfile. When your Dockerfile begins with `FROM codercom/code-server`, the active user is already `coder`.

To install system packages, you must add `USER root` before any `RUN apt-get` instructions.

For UID/GID parameterization, the `coder` user already exists at UID 1000. The adjustment steps are:
1. `groupmod -g ${USER_GID} coder`
2. `usermod -u ${USER_UID} -g ${USER_GID} coder`
3. `chown -R ${USER_UID}:${USER_GID} /home/coder` — required because files in `/home/coder` are still owned by the original UID 1000 on disk

Do this as the very first `RUN` after the ARG declarations — before installing any packages — so all subsequent operations have correct ownership.

---

### SSH_AUTH_SOCK Forwarding on WSL2

The SSH agent socket path on WSL2 is not fixed. It is typically something like `/run/user/1000/keyring/ssh` or `/tmp/ssh-XXXXXXXX/agent.XXXXX` and changes after reboots and agent restarts.

**Two-part solution:**

1. The developer sets `SSH_AUTH_SOCK` in `.env` to the output of `echo $SSH_AUTH_SOCK` in their WSL2 shell. This must be re-done if the path changes.

2. In `docker-compose.yml`, both the `environment` and `volumes` sections reference the same variable:
   ```yaml
   environment:
     - SSH_AUTH_SOCK=${SSH_AUTH_SOCK}
   volumes:
     - ${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}
   ```
   The volume mount makes the socket accessible inside the container at the same path. The env var tells SSH where to find it. Both must match.

3. The socket file is owned by the host user. Inside the container, `coder` must have the same UID as the host user for the socket to be accessible — this is the whole point of UID parameterization. UID mismatch = silent SSH agent failure.

4. If `SSH_AUTH_SOCK` is not set in `.env`, the volume entry resolves to `:` (invalid). Docker Compose will error. Emphasize this setup step in the README.

---

### Named Volume for Extensions

Code Server stores extensions at `/home/coder/.local/share/code-server/extensions` inside the container.

Mounting a named volume at this exact path preserves extensions across container restarts and recreations.

**How the hybrid model works:**
- On first container start, Docker creates the named volume populated with the image layer contents at that path — so baked-in extensions are present immediately.
- Extensions added interactively through the VS Code UI are written to the named volume and persist across restarts.
- **After a rebuild that adds new extensions to `extensions.txt`,** the new extensions are in the image layer but the existing named volume takes precedence — the new baked-in extensions will not appear unless the named volume is deleted.

**To update extensions after a rebuild:**
```sh
docker compose down
docker volume rm <project>_code-server-extensions
docker compose up -d
```

The named volume will be recreated from the fresh image with all baked-in extensions. Document this in the README under "Rebuilding the Image."

---

### settings.json Bind-Mount — Directory Pre-creation

If the directory `/home/coder/.local/share/code-server/User/` does not exist when Docker applies the bind-mount, Docker will create a **directory** named `settings.json` instead of a file. Code Server will then fail to read settings silently.

**Prevention:** Add this to the Dockerfile (as `USER coder`, before the bind-mount is relevant):
```dockerfile
RUN mkdir -p /home/coder/.local/share/code-server/User
```

---

### entrypoint.sh and exec

When you declare `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]` in your Dockerfile, you completely replace the base image's entrypoint. Your script is now responsible for eventually launching code-server.

**Before writing the entrypoint, inspect the base image:**
```sh
docker pull codercom/code-server:latest
docker inspect codercom/code-server:latest --format='{{.Config.Entrypoint}} {{.Config.Cmd}}'
```

Your entrypoint's final line is `exec "$@"`, which expands to the CMD passed by Docker (or whatever the base image's CMD is). Verify the base image's CMD so you know what `"$@"` will contain.

If the base image uses an ENTRYPOINT rather than a CMD, and you replace the ENTRYPOINT, you need to know what the base ENTRYPOINT would have called and call it yourself. A common pattern is to hardcode the final invocation if the base invocation is known and stable (e.g., `exec /usr/bin/code-server --bind-addr 0.0.0.0:8080 /home/coder/code`).

---

## Potential Gotchas

**Gotcha 1: Extensions install as wrong user**
If `code-server --install-extension` runs as `root` in the Dockerfile, extensions install to `/root/.local/share/code-server/extensions`. The `coder` user (which runs the container) cannot access them. Extensions appear absent. Always switch to `USER coder` before the extension install RUN step.

**Gotcha 2: settings.json created as directory**
If `/home/coder/.local/share/code-server/User/` doesn't exist at runtime, Docker creates a directory named `settings.json` instead of a file. Code Server falls back to defaults silently. Pre-create the directory in the Dockerfile.

**Gotcha 3: SSH_AUTH_SOCK not set in .env**
The volume entry `${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}` resolves to `:` if the variable is unset — invalid syntax. Docker Compose errors or ignores the entry. SSH agent forwarding fails. Emphasize this step in the README. The entrypoint script can warn if the variable is set but the socket path doesn't exist.

**Gotcha 4: UID mismatch causes wrong file ownership**
If `USER_UID` in `.env` doesn't match the WSL2 user's actual UID, files created inside the container appear on the host as owned by an unknown numeric UID. This breaks git and file watching. Verify with `id -u` on the host. Document this in the README.

**Gotcha 5: Named volume shadows rebuilt image extensions**
After a rebuild that adds extensions to `extensions.txt`, the existing named volume takes precedence over the new image contents. New baked-in extensions won't appear without deleting the volume. Document the rebuild process clearly.

**Gotcha 6: codercom/code-server base uses Debian, not Ubuntu**
Ondrej Sury's PHP PPA is for Ubuntu. For Debian (which the code-server base uses), the correct source is `packages.sury.org/php`. Repository setup commands differ. Verify the base OS with `cat /etc/os-release` in a running base container before writing the PHP install layer.

**Gotcha 7: Composer global packages installed as root aren't on coder's PATH**
If `composer global require` runs as root, packages land in `/root/.config/composer/vendor/bin` — not on `coder`'s PATH. Instead, download CLI tools (like Drush Launcher) as standalone phars to `/usr/local/bin/` and `chmod +x`. This puts them on PATH for all users without Composer global install complications.

**Gotcha 8: docker compose vs docker-compose**
Modern Docker ships `docker compose` (space, plugin), not `docker-compose` (hyphen, deprecated standalone binary). Use `docker compose` throughout the README. The standalone binary may not be present in the WSL2 Docker environment.
