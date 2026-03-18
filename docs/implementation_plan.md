# Implementation Plan: Portable Developer Environment

## Document Purpose

This document translates the PRD decisions and open questions into a concrete, step-by-step implementation guide. It resolves all open questions, defines every file to be created, explains Dockerfile layer ordering, and calls out tricky implementation details and gotchas.

---

## Resolved Open Questions

### 1. Drush Access Pattern
**Decision:** ~~Host terminal for Lando commands (Option A) is the baseline.~~ **[Revised]** Full Lando CLI is available inside the container via a path-translation wrapper. The Docker socket is always mounted.

**Revised justification:** The Docker socket mount (Option B security concern) is an acceptable trade-off given that the container runs as the host user (UID/GID match) and the environment is single-developer, local-only. The usability gain of having `lando drush`, `lando ssh`, and `lando start` work from the Code Server terminal outweighs the security consideration in this context.

**Implementation:** `lando-wrapper.sh` translates CWD from `/home/coder/code/*` to `$HOST_CODE_DIR/*` before invoking the real Lando binary (`/usr/local/bin/lando.real`). Two additional volume mounts support this: `~/.lando:/home/coder/.lando` (config/cache sharing) and `${HOST_CODE_DIR}:${HOST_CODE_DIR}` (code accessible at host paths for Lando project root matching). See CLAUDE.md for full details.

---

### 2. PHP Version Flexibility
**Decision:** Pin to PHP 8.3 as the single version. No `update-alternatives` multi-version support for MVP.

**Justification:** Drupal 10/11 require PHP 8.1+, and teams typically pin to one version per project. The Lando stack (not this container) runs PHP for the application — this container's PHP is primarily for Composer, linting, and static analysis. A single pinned version simplifies the image. Switching PHP versions requires a rebuild, which is acceptable. Expose a `PHP_VERSION` build arg to make the pin visible and easy to change.

---

### 2a. SSH Access
**Decision:** ~~SSH agent forwarding via `SSH_AUTH_SOCK`.~~ **[Revised]** Read-only bind-mount of `~/.ssh` into the container.

**Revised justification:** The `SSH_AUTH_SOCK` socket path on WSL2 changes after reboots and agent restarts, requiring manual `.env` updates. The bind-mount is simpler, requires no ongoing maintenance, and is secure given that the container runs as the same UID/GID as the host user. The mount is read-write (not read-only) to allow `known_hosts` updates when connecting to new servers.

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

### Phase 3 — SSH Key Access and Git Configuration
**Goal:** ~~SSH agent socket is forwarded into the container.~~ **[Revised — uses bind-mount]** Host `~/.ssh` is mounted read-only into the container. Git is configured with the identity from `.env`. `git push` works from the Code Server terminal.

**Success test:** Open a Code Server terminal and run `ssh -T git@github.com`. Confirm successful authentication. Run `git config --global user.name` and confirm it matches `GIT_USER_NAME` in `.env`.

**Files created or modified in this phase:**
- `entrypoint.sh` (new — handles git config and execs code-server)
- `docker-compose.yml` (add `~/.ssh:ro` mount and git environment variables)
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
**Goal:** Document optional mounts, finalize the README with full setup instructions, and add the override example file.

**Success test:** Follow the README setup instructions on a clean machine from scratch. The environment is running within 5 minutes.

**Files created or modified in this phase:**
- `docker-compose.override.yml.example` (new)
- `README.md` (completed)

---

### Phase 6 — Lando CLI Integration
**Goal:** Full Lando CLI available inside the container terminal. `lando start`, `lando drush`, `lando ssh`, etc. work as if running from the host.

**Success test:** From the Code Server terminal, `cd` into a Lando project and run `lando drush status`. Confirm it returns site status from the running Lando appserver container.

**Files created or modified in this phase:**
- `lando-wrapper.sh` (new — path-translation wrapper)
- `Dockerfile` (add Lando npm install, copy wrapper)
- `docker-compose.yml` (add `~/.lando` volume, `${HOST_CODE_DIR}:${HOST_CODE_DIR}` volume, `HOST_CODE_DIR` env var)

---

## File-by-File Specification

### `Dockerfile`

The most critical file. Every layer ordering decision has cache implications.

**Layer order and rationale:**

1. `FROM codercom/code-server:<version>` — The base provides Debian (bookworm), the `coder` user at UID 1000, and a working `code-server` binary. **Pin to a specific version tag** (not `latest`) for reproducibility. `latest` is acceptable during initial development.

2. `ARG USER_UID=1000` / `ARG USER_GID=1000` / `ARG DOCKER_GID=1001` / `ARG PHP_VERSION=8.3` / `ARG NODE_MAJOR=22` / `ARG LANDO_VERSION=3.26.2` — Declare all build args immediately after FROM so they are available throughout the build. These are build args, not ENV vars — they are only needed during the build.

3. `USER root` — The base image drops to `coder` at the end of its own Dockerfile. Switch back to root to install system packages.

4. `RUN` — **UID/GID adjustment.** Modify the existing `coder` user and group to match the `USER_UID`/`USER_GID` build args using `usermod` and `groupmod`. Then `chown -R` the home directory. Do this first, before installing anything, so all subsequent ownership is correct. See Tricky Details for the specifics.

4a. `RUN groupadd -g ${DOCKER_GID} docker && usermod -aG docker coder` — Create a `docker` group matching the host socket GID and add `coder` to it. Must happen before switching to `coder` so the group membership is baked in.

5. `RUN` — **System prerequisites.** Install `curl`, `git`, `gnupg`, `gosu`, `lsb-release`, `ca-certificates`, `dnsmasq`, `iproute2`, and anything needed to add third-party package repositories. `gosu` is required by entrypoint.sh for privilege drop; `dnsmasq` and `iproute2` are used to resolve `*.lndo.site` from inside the container. This layer changes infrequently — near the top for maximum cache reuse.

6. `RUN` — **Add PHP repository.** Add the Ondrej Sury Debian PHP repository (note: Debian variant, not Ubuntu — see Gotcha 6). Separate from the install step so that changing the package list below gets a cache hit on the repo-add step.

7. `RUN` — **Install PHP + extensions.** Install `php${PHP_VERSION}-cli` and the following extensions: `mbstring`, `xml`, `curl`, `zip`, `gd`, `intl`, `mysql`, `pgsql`, `sqlite3`, `bcmath`. Add `xdebug` if local debugging is desired. End with `rm -rf /var/lib/apt/lists/*` to clean the apt cache in the same layer.

8. `RUN` — **Install Composer.** Use the official installer: download `composer-setup.php`, verify the checksum against the published hash, run the installer with `--install-dir=/usr/local/bin --filename=composer`, remove the installer. Do not use the apt package — it lags behind.

9. `RUN` — **Add NodeSource repository.** Use the official NodeSource setup script for `NODE_MAJOR`. Separate layer for the same cache reason as PHP.

10. `RUN` — **Install Node.js, npm, yarn.** `apt-get install nodejs` after NodeSource is active. Install yarn via `npm install -g yarn` (the apt package is outdated). Clean apt cache.

11. `RUN` — **Install Python 3 and pip.** Python 3 is often pre-installed on Debian-based images; explicitly install `python3-pip` and `python3-venv`. Clean apt cache.

11a. `RUN` — **Install uv.** Use the official installer from `astral.sh/uv/install.sh`. Move the binaries (`uv`, `uvx`) from `/root/.local/bin/` to `/usr/local/bin/` so they're available to all users.

12. `RUN` — **Install global Drupal tooling.** Install Drush Launcher as a global tool. The correct approach is to download the drush launcher phar to `/usr/local/bin/drush` and `chmod +x` it — this puts it on PATH for all users without Composer global install complications. See Gotcha 7 for why `composer global require` as root is problematic.

12a. `RUN` — **Install Docker CLI + Compose plugin.** Add the official Docker apt repository and install `docker-ce-cli` and `docker-compose-plugin`. This provides the `docker` and `docker compose` commands connected to the host daemon via the mounted socket. Only the CLI is needed — the host daemon handles container execution.

12b. `RUN npm install -g @lando/core@${LANDO_VERSION}` — Install Lando CLI as a global npm package (not via the `lando` installer binary). Rename the real binary: `ln -sf $(npm root -g)/@lando/core/bin/lando /usr/local/bin/lando.real`.

12c. `COPY lando-wrapper.sh /usr/local/bin/lando` — Install the path-translation wrapper as the `lando` command. `chmod +x` in the same or following `RUN` step.

13. `USER coder` — Switch to the `coder` user before installing extensions, so they land in `coder`'s home directory. **This switch must happen before the extension install step.** See Gotcha 1.

14. `RUN mkdir -p /home/coder/.local/share/code-server/User` — Pre-create the settings directory as the `coder` user. This prevents Docker from creating a directory named `settings.json` when the bind-mount is applied. See Gotcha 2.

15. `COPY extensions.txt /home/coder/extensions.txt` — Copy the extensions list. Placed after system installs (which change rarely) and as the `coder` user (for correct ownership).

16. `RUN` — **Install core VS Code extensions.** Iterate over `extensions.txt` and call `code-server --install-extension <id>` for each. Must run as `coder`. Extensions install to `/home/coder/.local/share/code-server/extensions/`.

17. `USER root` — Switch back to root before copying the entrypoint, since `entrypoint.sh` now runs as root and drops to `coder` via `gosu`.
    `COPY entrypoint.sh /usr/local/bin/entrypoint.sh`
    `RUN chmod +x /usr/local/bin/entrypoint.sh`

18. `WORKDIR /home/coder/code` — Set the default working directory to the mounted code volume so new terminals open there.

19. `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]` — Override the base image's entrypoint with our script. The script is responsible for eventually calling code-server. See Tricky Details on `exec "$@"`.

---

### `docker-compose.yml`

**Key configuration items:**

- `build.context: .` and `build.args` block — pass `USER_UID`, `USER_GID`, and `DOCKER_GID` from `.env` to the build process. `DOCKER_GID` must match the host Docker socket GID.

- `ports` — map `${CODE_SERVER_PORT}:8080`. Code Server listens on 8080 inside the container by default.

- `extra_hosts: host.docker.internal:host-gateway` — adds a `/etc/hosts` entry resolving `host.docker.internal` to the Docker bridge gateway. Required so the container can reach host services and for dnsmasq *.lndo.site routing.

- `environment` block:
  - `PASSWORD=${CODE_SERVER_PASSWORD}` — the specific env var name code-server reads for auth
  - `GIT_USER_NAME`, `GIT_USER_EMAIL` — passed to entrypoint for git config
  - `HOST_CODE_DIR` — used by `lando-wrapper.sh` for CWD path translation
  - `HOST_HOME_DIR` — used by entrypoint to set up home directory symlink so `os.homedir()` returns the host path
  - `GH_TOKEN=${GITHUB_TOKEN}` — GitHub CLI reads `GH_TOKEN` for authentication
  - `ACQUIA_KEY`, `ACQUIA_SECRET`, `ACSF_API_KEY`, `ACSF_USERNAME` — Acquia/ACSF credentials
  - `OPENAI_KEY`, `HOMEASSISTANT_WEBHOOK`, `CLAUDE_STOP_WEBHOOK_URL` — integration webhooks
  - `VAULT_ADDR`, `VAULT_USER`, `VAULT_PASS` — HashiCorp Vault connection details

- `volumes` block:
  1. `${HOST_CODE_DIR}:/home/coder/code` — host code directory at container path, read-write
  2. `${HOST_CODE_DIR}:${HOST_CODE_DIR}` — same directory mounted at its host path so translated Lando CWD paths resolve inside the container
  3. `~/.lando:/home/coder/.lando` — shares host Lando config, cache, and certificates
  4. `code-server-extensions:/home/coder/.local/share/code-server/extensions` — named volume for extension persistence
  5. `./config/settings.json:/home/coder/.local/share/code-server/User/settings.json` — bind-mount, read-write (so UI edits flow back to the repo file)
  6. `~/.ssh:/home/coder/.ssh` — SSH keys from host, read-write (allows `known_hosts` updates)
  7. `npm-cache:/home/coder/.npm` — named volume for npm cache persistence
  8. `${CLAUDE_CONFIG_DIR:-~/.claude}:/home/coder/.claude` — Claude Code credentials passthrough
  9. `${CLAUDE_CREDENTIALS:-~/.claude.json}:/home/coder/.claude.json` — Claude Code credentials passthrough
  10. `./claude-config:/home/coder/claude-config` — portable Claude Code customizations (commands, agents, settings, MCP config)
  11. `/var/run/docker.sock:/var/run/docker.sock` — Docker socket for Docker CLI and Lando CLI

- `volumes` top-level — declare: `code-server-extensions: {}` and `npm-cache: {}`

- `restart: unless-stopped` — useful for a dev tool that should survive reboots.

---

### `docker-compose.override.yml.example`

Documents optional per-developer volume mounts that users can activate by copying to `docker-compose.override.yml` (gitignored).

**Content:**
- Acquia Cloud credentials mount: `~/.acquia:/home/coder/.acquia:ro` — for Acquia CLI access
- Clear comment that this file is an example and `docker-compose.override.yml` must never be committed
- Note that Docker socket, Docker CLI, and Lando CLI are already built into the base `docker-compose.yml` — no override needed for those

---

### `.env.example`

Committed to the repo. Documents every variable with example values for non-secret vars and blank/placeholder values for secrets.

**Variables:**
```
CODE_SERVER_PORT=8080
CODE_SERVER_PASSWORD=          # Required. Set a strong password.
HOST_HOME_DIR=/home/your-username  # Absolute host home path; find with: echo $HOME
HOST_CODE_DIR=/home/your-username/code
USER_UID=1000                  # Match output of: id -u
USER_GID=1000                  # Match output of: id -g
DOCKER_GID=1001                # Match output of: stat -c '%g' /var/run/docker.sock
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=you@example.com
GITHUB_TOKEN=                  # Optional; for gh CLI and private repo access
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

The build context only needs: `Dockerfile`, `entrypoint.sh`, `lando-wrapper.sh`, `extensions.txt`, `config/settings.json`.

---

### `entrypoint.sh`

Runs every time the container starts as **root** (the Dockerfile's final `USER` is `root`). Drops to `coder` at the end via `gosu`. Must be minimal and fast.

**Responsibilities in order:**

1. `set -euo pipefail` — strict mode so any error is immediately visible.

2. **Home directory setup** — If `HOST_HOME_DIR` is set and differs from `/home/coder`:
   - `usermod -d "${HOST_HOME_DIR}" coder` — tells the OS (and `os.homedir()` in Node.js) that coder's home is the host path
   - `mkdir -p "${HOST_HOME_DIR}" && chown coder:coder "${HOST_HOME_DIR}"` — create the directory if needed
   - Symlink every dotfile from `/home/coder/.[!.]*` into `${HOST_HOME_DIR}/` — so tools using `HOME` find their config at the expected path (e.g., `~/.lando`, `~/.ssh`, `~/.claude`)

3. **dnsmasq for *.lndo.site** — Detect the default gateway IP via `ip route`, write a dnsmasq config resolving `*.lndo.site` to that IP, start `dnsmasq`, and prepend `nameserver 127.0.0.1` to `/etc/resolv.conf`. Note: `/etc/resolv.conf` is a Docker bind-mount so `sed -i` (which renames) fails — use a temp copy and `cat` instead. This lets the Code Server browser (and curl inside the container) reach Lando development URLs.

4. **Configure git global identity** via `gosu coder git config --global ...` from `GIT_USER_NAME` and `GIT_USER_EMAIL`. Emit a warning if either is unset.

5. **Claude Code configuration sync** — If `claude-config/` is mounted at `/home/coder/claude-config`:
   - Symlink `commands/` and `agents/` files into `~/.claude/commands/` and `~/.claude/agents/` (preserves existing non-repo files)
   - Symlink `default_mcp.json` into `~/.claude/`
   - Merge `settings.json`: base settings from repo win for everything except `permissions` (preserved from existing `~/.claude/settings.json`), using a Python one-liner for JSON merge
   - `chown -R coder:coder ~/.claude`

6. **Validate SSH keys (optional but helpful):** Check that `~/.ssh` is accessible. Emit a warning if not; do not exit.

7. **Environment variable persistence** — Write all Docker-injected env vars (`GITHUB_TOKEN`, `GIT_USER_NAME`, `HOST_CODE_DIR`, `HOST_HOME_DIR`, `ACQUIA_KEY`, `VAULT_ADDR`, etc.) to `~/.docker-env` as `export VAR=VALUE` lines. Append a source line to `~/.bashrc` (idempotent — only adds once). This is necessary because Code Server's integrated terminal spawns new bash sessions that don't inherit PID 1's environment.

8. `exec gosu coder "$@"` — **Critical.** Drops to the `coder` user and replaces the shell process with the code-server command so signals (SIGTERM, SIGINT) pass through correctly.

**What the script must NOT do:**
- Install extensions (done at build time — do not slow down every startup)
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
anthropic.claude-code                  # Official Claude Code extension
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

1. **Prerequisites** — WSL2, Docker (WSL2 backend), Lando installed on host, SSH keys in `~/.ssh`
2. **First-Time Setup** — clone, copy `.env.example` → `.env`, fill in values (including `HOST_HOME_DIR`, `HOST_CODE_DIR`, `DOCKER_GID`), `docker compose build`, `docker compose up -d`, open browser
3. **Daily Usage** — `docker compose up -d` / `docker compose down`, URL
4. **Lando Workflow** — run `lando` commands directly from the Code Server terminal; explain the path-translation wrapper; list requirements (`HOST_CODE_DIR`, `DOCKER_GID`, host Lando installation)
5. **Adding Extensions** — hybrid model explained; add to `extensions.txt` + rebuild for permanent additions, or install interactively for session-persistent additions
6. **Rebuilding the Image** — `docker compose down`, optionally `docker volume rm <project>_code-server-extensions` (required if extensions changed), `docker compose build`, `docker compose up -d`
7. **Changing PHP/Node Versions** — explain the build args
8. **Optional Mounts** — document the override file for Acquia credentials and other per-developer mounts
9. **Troubleshooting** — common failure modes from the Gotchas section below

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

### SSH Key Access — Bind-Mount Approach

**[Implementation note: agent forwarding was planned but bind-mount was chosen instead — see Resolved Open Questions.]**

The host `~/.ssh` directory is mounted read-write into the container:
```yaml
volumes:
  - ~/.ssh:/home/coder/.ssh
```

This works because:
- `coder` user has the same UID as the host user (UID 1000 by default), so key file permissions (`600`) are respected
- Read-write mount allows the container to update `known_hosts` when connecting to new servers
- No socket path management or re-configuration after reboots

If keys require passphrases, users are prompted interactively in the terminal (this works fine in code-server's integrated terminal).

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

**Gotcha 3: DOCKER_GID mismatch breaks Docker socket access**
`DOCKER_GID` in `.env` must match the GID of the host Docker socket (`stat -c '%g' /var/run/docker.sock`). If it doesn't, the container's `coder` user cannot access the socket and `docker` / `lando` commands fail with permission errors. Changing `DOCKER_GID` requires a rebuild (`docker compose build`) since it is a build arg used to create the `docker` group inside the image.

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
