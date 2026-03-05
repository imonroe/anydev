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
- Declarative VS Code extension management via `extensions.txt`
- Settings synced via git through `config/settings.json`

## How It Works

Your code lives on the host filesystem (`~/code`) and is mounted into the container as a volume. The container provides the tooling; your files stay on disk and are never at risk when the container is rebuilt or removed.

[Lando](https://lando.dev/) continues to manage application stacks (web server, database, PHP-FPM) independently on the host. The Code Server container handles editing via the VS Code interface and provides a terminal for git, Composer, and npm — not the application runtime.

---

## Prerequisites

- **WSL2** with a Linux distribution installed
- **Docker** with the WSL2 backend enabled
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

Lando commands run in a **separate WSL2 terminal** on the host — not inside Code Server:

```sh
# In a WSL2 host terminal:
cd ~/code/my-drupal-site
lando start
lando drush cr
```

Use the Code Server terminal for git, Composer, npm, and Python tasks:

```sh
# In Code Server terminal:
cd /home/coder/code/my-drupal-site
git pull
composer install
npm run build
```

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

## Advanced: Docker Socket Access

To run Docker or Lando commands from inside the Code Server terminal, you can mount the host Docker socket. **This grants the container root-equivalent access to the host Docker daemon.**

```sh
cp docker-compose.override.yml.example docker-compose.override.yml
docker compose up -d
```

See `docker-compose.override.yml.example` for details and security warnings.

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

---

## Project Structure

```
anydev/
├── Dockerfile                          # Image definition
├── docker-compose.yml                  # Service configuration
├── docker-compose.override.yml.example # Optional local overrides (e.g., Docker socket)
├── .env.example                        # Required environment variables
├── .dockerignore                       # Build context filtering
├── entrypoint.sh                       # Container startup script
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
