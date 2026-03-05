# anydev

A portable, self-contained development environment running in Docker. Provides a browser-accessible VS Code interface ([code-server](https://github.com/coder/code-server)) with PHP, Node.js, and Python pre-installed — spin up an identical environment on any machine with WSL2 and Docker.

Built for PHP/Drupal development, with Composer, Drush Launcher, and a curated set of VS Code extensions included out of the box.

---

## What's Included

- **Code Server** — VS Code in the browser, accessible on a configurable local port
- **PHP 8.3** + Composer + Drush Launcher
- **Node.js 22 LTS** + npm + yarn
- **Python 3** + pip
- **Git** with SSH key access via read-only `~/.ssh` mount
- **Docker CLI** — connected to the host Docker daemon via mounted socket
- **Lando CLI** — fully functional inside the container (see [Lando Workflow](#lando-workflow))
- **GitHub CLI** (`gh`)
- **Claude Code** (`claude`) — authenticated via host credentials bind-mount
- Declarative VS Code extension management via `extensions.txt`
- Settings synced via git through `config/settings.json`

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
   ```
   Set `CODE_SERVER_PASSWORD` to a strong password. Set `HOST_CODE_DIR` to the absolute path of your code directory (e.g., `/home/ian/code`). Fill in `GIT_USER_NAME` and `GIT_USER_EMAIL`.

4. **Build and start:**
   ```sh
   docker compose build
   docker compose up -d
   ```

5. **Open Code Server:**
   Navigate to `http://localhost:8080` (or your configured `CODE_SERVER_PORT`) and enter your password.

---

## SSH Setup

Your host `~/.ssh` directory is mounted read-only into the container. As long as your SSH keys exist on the host, git operations over SSH will work inside the container with no additional configuration.

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

**Requirements for Lando to work:**
- `HOST_CODE_DIR` must be set correctly in `.env` (the absolute path of your code dir on the host)
- Lando must be installed on the host (the container shares the host's `~/.lando` config)
- The Docker socket GID in `DOCKER_GID` must match the host (`stat -c '%g' /var/run/docker.sock`)

**Limitations:**
- `lando start` for projects outside `HOST_CODE_DIR` will not benefit from path translation
- Lando certs generated inside the container go to `~/.lando` on the host (shared config — this is correct behavior)

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
- Confirm the project's `.lando.yml` is inside `HOST_CODE_DIR`
- Verify `~/.lando` on the host is populated (Lando must have been run on the host at least once)

**Lando Docker permission denied:**
- `DOCKER_GID` in `.env` must match the host Docker socket GID: `stat -c '%g' /var/run/docker.sock`
- Rebuild after changing the GID: `docker compose build && docker compose up -d`

**`lando start` mounts wrong paths:**
- This indicates `HOST_CODE_DIR` is set incorrectly — the wrapper translates paths using this value

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
└── docs/
    ├── product_requirements.md         # Full PRD
    └── implementation_plan.md          # Architecture and implementation details
```

---

## License

MIT
