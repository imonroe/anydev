# anydev

A portable, self-contained development environment running in Docker. Provides a browser-accessible VS Code interface ([code-server](https://github.com/coder/code-server)) with PHP, Node.js, and Python pre-installed — spin up an identical environment on any machine with WSL2 and Docker.

Built for PHP/Drupal development, with Composer, Drush Launcher, and a curated set of VS Code extensions included out of the box.

---

## What's Included

- **Code Server** — VS Code in the browser, accessible on a configurable local port
- **PHP 8.3** + Composer + Drush Launcher + Xdebug
- **Node.js 22 LTS** + npm + yarn
- **Python 3** + pip + venv + [uv](https://github.com/astral-sh/uv) (fast Python package manager)
- **Git** with SSH key access via `~/.ssh` mount (read-write for `known_hosts` updates)
- **Docker CLI + Compose plugin** — connected to the host Docker daemon via mounted socket
- **Lando CLI** — fully functional inside the container (see [Lando Workflow](#lando-workflow))
- **GitHub CLI** (`gh`) — authenticated via `GITHUB_TOKEN` env var
- **Claude Code** (`claude`) — authenticated via host credentials bind-mount, with portable customizations in `claude-config/`
- Declarative VS Code extension management via `extensions.txt`
- Settings synced via git through `config/settings.json`
- **dnsmasq** — resolves `*.lndo.site` URLs from inside the container so Lando dev sites are reachable

## How It Works

Your code lives on the host filesystem (`~/code`) and is mounted into the container as a volume. The container provides the tooling; your files stay on disk and are never at risk when the container is rebuilt or removed.

The host Docker socket is mounted into the container, giving the Docker CLI and Lando CLI direct access to the host Docker daemon. Lando environments started from inside Code Server create and manage containers on the host exactly as they would from a host terminal.

---

## Prerequisites

- **WSL2** with a Linux distribution installed
- **Docker** with the WSL2 backend enabled
- **Lando** installed on the host (the container uses the host's `~/.lando` config and daemon)
- **SSH keys** in `~/.ssh` on the host (for git push/pull)

---

## First-Time Setup

1. **Clone this repository:**
   ```sh
   git clone <repo-url> && cd anydev
   ```

2. **Create your `.env` file:**
   ```sh
   cp .env.example .env
   ```

3. **Fill in your `.env` values:**
   ```sh
   # Find your UID/GID
   id -u    # USER_UID
   id -g    # USER_GID

   # Find the Docker socket GID
   stat -c '%g' /var/run/docker.sock    # DOCKER_GID

   # Find your home directory
   echo $HOME    # HOST_HOME_DIR
   ```
   Required values:
   - `CODE_SERVER_PASSWORD` — a strong password for the web UI
   - `HOST_HOME_DIR` — absolute path to your home directory on the host (e.g., `/home/ian`)
   - `HOST_CODE_DIR` — absolute path to your code directory (e.g., `/home/ian/code`)
   - `GIT_USER_NAME` and `GIT_USER_EMAIL` — your git identity
   - `CLAUDE_CONFIG_DIR` and `CLAUDE_CREDENTIALS` — absolute paths to your Claude Code config (e.g., `/home/ian/.claude` and `/home/ian/.claude.json`). **Use absolute paths — Docker Compose does not expand `~` in `.env` values.**

4. **Build and start:**
   ```sh
   docker compose build
   docker compose up -d
   ```

5. **Open Code Server:**
   Navigate to `http://localhost:8080` (or your configured `CODE_SERVER_PORT`) and enter your password.

---

## SSH Setup

Your host `~/.ssh` directory is mounted read-write into the container. This allows git operations over SSH to work, and lets the container update `known_hosts` when connecting to new servers for the first time.

Test from inside the Code Server terminal:
```sh
ssh -T git@github.com
```

If your keys require a passphrase, you'll be prompted when using them inside the container.

---

## Daily Usage

```sh
# Start the environment
docker compose up -d

# Stop the environment
docker compose down

# View logs
docker compose logs -f code-server
```

Access Code Server at `http://localhost:8080` (or your configured port).

---

## Lando Workflow

Lando commands work directly from the Code Server terminal — no need for a separate host terminal:

```sh
# In the Code Server terminal:
cd /home/coder/code/my-drupal-site
lando start
lando drush cr
lando ssh
```

**How it works:** A path-translation wrapper intercepts `lando` calls and maps the container code path (`/home/coder/code/...`) to its equivalent host path (e.g., `/home/ian/code/...`) before invoking Lando. This ensures Lando finds registered projects, correctly mounts volumes when starting new environments, and communicates with existing containers — all via the mounted Docker socket.

Additionally, the entrypoint sets up `HOST_HOME_DIR` so that `os.homedir()` (used by Lando internally) returns the host path, ensuring generated Docker Compose bind-mount paths are valid on the host.

**dnsmasq and `*.lndo.site` resolution:** The entrypoint starts a local dnsmasq instance that resolves `*.lndo.site` domains to the Docker host gateway IP. This means you can `curl` or browse Lando development URLs from inside the container.

**Requirements for Lando to work:**
- `HOST_CODE_DIR` must be set correctly in `.env` (the absolute path of your code dir on the host)
- `HOST_HOME_DIR` must be set correctly in `.env` (the absolute path of your home dir on the host)
- Lando must be installed on the host (the container shares the host's `~/.lando` config)
- The Docker socket GID in `DOCKER_GID` must match the host (`stat -c '%g' /var/run/docker.sock`)

**Limitations:**
- `lando start` for projects outside `HOST_CODE_DIR` will not benefit from path translation
- Lando certs generated inside the container go to `~/.lando` on the host (shared config — this is correct behavior)

---

## Claude Code

Claude Code is installed globally in the container and authenticated via bind-mounted host credentials (`~/.claude` and `~/.claude.json`). Run `claude` on the host first to complete the initial OAuth login, then it works inside the container automatically.

### Portable Customizations (`claude-config/`)

The `claude-config/` directory holds portable Claude Code configuration that travels with the repo. At container startup, `entrypoint.sh` syncs these into `~/.claude/`:

- **`commands/`** — Custom slash commands, symlinked into `~/.claude/commands/`. Edits inside the container write back to the repo.
- **`agents/`** — Custom agent definitions, symlinked into `~/.claude/agents/`.
- **`default_mcp.json`** — MCP server definitions, symlinked into `~/.claude/`.
- **`settings.json`** — Base settings (hooks, model, plugins). Merged into `~/.claude/settings.json` at startup, preserving any existing `permissions` block (which is machine-specific).

**Adding a new command or agent:** Create the file in `claude-config/commands/` or `claude-config/agents/`, commit, and it will be available on any machine running this container.

**Changing hooks or plugins:** Edit `claude-config/settings.json`. The change applies on next container restart.

**Machine-specific overrides:** `~/.claude/settings.local.json` is never touched by the merge and remains local.

---

## Adding Extensions

**For permanent additions** (persist across rebuilds):
1. Add the extension ID to `extensions.txt`
2. Rebuild: `docker compose build && docker compose up -d`
3. If extensions don't appear, delete the named volume (see Rebuilding below)

**For session-persistent additions** (persist across restarts, not rebuilds):
- Install interactively through the Code Server Extensions panel
- These are stored in a named Docker volume

---

## Rebuilding the Image

When you change the Dockerfile, extensions.txt, or entrypoint.sh:

```sh
docker compose down
docker compose build
docker compose up -d
```

If you added new extensions to `extensions.txt` and they don't appear, the named volume is caching old extensions:

```sh
docker compose down
docker volume rm anydev_code-server-extensions
docker compose build
docker compose up -d
```

---

## Changing PHP or Node Versions

Edit the build args in `docker-compose.yml` or pass them on the command line:

```sh
docker compose build --build-arg PHP_VERSION=8.2 --build-arg NODE_MAJOR=20
docker compose up -d
```

---

## Advanced: Optional Mounts

The `docker-compose.override.yml.example` file contains optional volume mounts you can activate by copying and uncommenting:

```sh
cp docker-compose.override.yml.example docker-compose.override.yml
# Edit the file and uncomment the mounts you need
docker compose up -d
```

**Available options:**
- **Acquia Cloud credentials** — Mount `~/.acquia` read-only for Acquia CLI access

---

## Environment Variables

All environment variables are configured in `.env` (copied from `.env.example`). Key variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `CODE_SERVER_PORT` | Host port for the Code Server web UI (default: 8080) | No |
| `CODE_SERVER_PASSWORD` | Password for Code Server login | Yes |
| `HOST_HOME_DIR` | Absolute host home directory path (e.g., `/home/ian`) | Yes |
| `HOST_CODE_DIR` | Absolute host code directory path (e.g., `/home/ian/code`) | Yes |
| `USER_UID` / `USER_GID` | Must match host user (`id -u`, `id -g`) | Yes |
| `DOCKER_GID` | Host Docker socket GID (`stat -c '%g' /var/run/docker.sock`) | Yes |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | Git identity inside the container | Yes |
| `GITHUB_TOKEN` | Personal access token for `gh` CLI | No |
| `CLAUDE_CONFIG_DIR` | Absolute path to `~/.claude` on host | No (defaults to `~/.claude`) |
| `CLAUDE_CREDENTIALS` | Absolute path to `~/.claude.json` on host | No (defaults to `~/.claude.json`) |
| `ACQUIA_KEY` / `ACQUIA_SECRET` | Acquia Cloud API credentials | No |
| `ACSF_API_KEY` / `ACSF_USERNAME` | Acquia Site Factory credentials | No |
| `VAULT_ADDR` / `VAULT_USER` / `VAULT_PASS` | HashiCorp Vault connection details | No |
| `CLAUDE_STOP_WEBHOOK_URL` | Webhook called when Claude Code finishes a task | No |

See `.env.example` for the full list with descriptions.

---

## Troubleshooting

**SSH not working:**
- Verify your keys exist at `~/.ssh` on the host (e.g., `~/.ssh/id_ed25519`)
- Ensure your host UID matches `USER_UID` in `.env` (`id -u` to check) — UID mismatch can prevent reading the mounted keys
- Check permissions: keys should be `600`, the `.ssh` directory should be `700`

**Files have wrong ownership on host:**
- `USER_UID` and `USER_GID` in `.env` must match your WSL2 user (`id -u`, `id -g`)
- Rebuild after changing: `docker compose build && docker compose up -d`

**Extensions missing after rebuild:**
- Named volume caches old extensions — delete it:
  ```sh
  docker volume rm anydev_code-server-extensions
  ```

**Code Server shows default settings:**
- Ensure `config/settings.json` exists before starting the container
- Check that the file is not empty and contains valid JSON

**`docker compose up` fails with invalid volume:**
- Ensure `HOST_CODE_DIR` is set in `.env` to a valid absolute path

**Lando can't find project / "not in a lando app":**
- Confirm `HOST_CODE_DIR` in `.env` matches the actual path of your code on the host
- Confirm `HOST_HOME_DIR` in `.env` matches your actual home directory on the host
- Confirm the project's `.lando.yml` is inside `HOST_CODE_DIR`
- Verify `~/.lando` on the host is populated (Lando must have been run on the host at least once)

**Lando Docker permission denied:**
- `DOCKER_GID` in `.env` must match the host Docker socket GID: `stat -c '%g' /var/run/docker.sock`
- Rebuild after changing the GID: `docker compose build && docker compose up -d`

**`lando start` mounts wrong paths:**
- This indicates `HOST_CODE_DIR` or `HOST_HOME_DIR` is set incorrectly

**`*.lndo.site` URLs not resolving inside the container:**
- The dnsmasq service should start automatically via `entrypoint.sh`
- Check container logs for dnsmasq errors: `docker compose logs code-server`

**Claude Code not authenticating:**
- Run `claude` on the host first to complete OAuth login
- Ensure `CLAUDE_CONFIG_DIR` and `CLAUDE_CREDENTIALS` in `.env` use absolute paths (not `~`)

**Environment variables not available in Code Server terminal:**
- The entrypoint writes env vars to `~/.docker-env` which is sourced from `~/.bashrc`
- If you added new variables, restart the container

---

## Project Structure

```
anydev/
├── Dockerfile                          # Image definition
├── docker-compose.yml                  # Service configuration
├── docker-compose.override.yml.example # Optional local overrides
├── .env.example                        # Required environment variables
├── .dockerignore                       # Build context filtering
├── entrypoint.sh                       # Container startup script
├── lando-wrapper.sh                    # Lando path-translation wrapper
├── extensions.txt                      # Declarative VS Code extension list
├── config/
│   └── settings.json                   # VS Code settings (committed, bind-mounted)
├── claude-config/                      # Portable Claude Code customizations
│   ├── commands/                       # Custom slash commands (symlinked into ~/.claude/)
│   ├── agents/                         # Custom agent definitions (symlinked into ~/.claude/)
│   ├── settings.json                   # Base Claude settings (hooks, model, plugins)
│   └── default_mcp.json               # MCP server definitions
├── docs/
│   ├── product_requirements.md         # Full PRD
│   └── implementation_plan.md          # Architecture and implementation details
├── CLAUDE.md                           # AI assistant project guide
└── README.md                           # This file
```

---

## License

MIT
