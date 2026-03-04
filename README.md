# anydev

A portable, self-contained development environment running in Docker. Provides a browser-accessible VS Code interface ([code-server](https://github.com/coder/code-server)) with PHP, Node.js, and Python pre-installed — spin up an identical environment on any machine with WSL2 and Docker.

Built for PHP/Drupal development, with Composer, Drush Launcher, and a curated set of VS Code extensions included out of the box.

---

## What's included

- **Code Server** — VS Code in the browser, accessible on a configurable local port
- **PHP 8.3** + Composer + Drush Launcher
- **Node.js LTS** + npm + yarn
- **Python 3** + pip
- **Git** with SSH agent forwarding for push/pull access
- Declarative VS Code extension management via `extensions.txt`
- Settings synced via git through `config/settings.json`

## How it works

Your code lives on the host filesystem (`~/code`) and is mounted into the container as a volume. The container provides the tooling; your files stay on disk and are never at risk when the container is rebuilt or removed.

[Lando](https://lando.dev/) continues to manage application stacks (web server, database, PHP-FPM) independently on the host. The Code Server container handles editing, git, Composer, and npm — not the application runtime.

---

## Setup

See [`docs/implementation_plan.md`](docs/implementation_plan.md) for the full implementation plan and architecture decisions.

> This project is currently in development. Setup instructions will be added here once the initial build is complete.

---

## Project structure

```
anydev/
├── Dockerfile                          # Image definition
├── docker-compose.yml                  # Service configuration
├── docker-compose.override.yml.example # Optional local overrides (e.g. Docker socket)
├── .env.example                        # Required environment variables
├── entrypoint.sh                       # Container startup script
├── extensions.txt                      # Declarative VS Code extension list
├── config/
│   └── settings.json                   # VS Code settings (committed, bind-mounted)
└── docs/
    ├── product_requirements.md
    └── implementation_plan.md
```

---

## License

MIT
