# PHP stack on Apple container

A native-PHP sample stack — **nginx + PHP-FPM + MySQL + phpMyAdmin** — running on [Apple's `container` CLI](https://github.com/apple/container) instead of Docker. Everything is orchestrated by a Makefile; there is no docker-compose. The app itself is a single PDO page that counts visits and shows the stack's versions.

## Requirements

- macOS 26+ on Apple silicon
- [Apple container](https://github.com/apple/container) 1.0+ — install the signed `.pkg` from the [releases page](https://github.com/apple/container/releases)
- GNU make (ships with the Xcode Command Line Tools)

## Quick start

```sh
make env    # create .env from .env.example
make start  # create containers and wire everything up (builds images on first run)
make check  # verify both endpoints respond
```

Then open:

- **http://app.localhost** — the app
- **http://phpmyadmin.localhost** — phpMyAdmin (auto-login as root)

Any `*.localhost` domain resolves to loopback on macOS natively — no `/etc/hosts` editing needed.

## What you get

| Service    | Image (built from `server/*/Containerfile`) | Notes |
|------------|---------------------------------------------|-------|
| nginx      | `nginx:1-alpine`                            | Fronts both domains on port 80 |
| PHP-FPM    | `php:8.5-fpm-alpine`                        | PDO/MySQL, Xdebug (trigger mode), timezonedb, Composer, UTC |
| MySQL      | `mysql:9`                                   | UTC server timezone, data persists in a named volume |
| phpMyAdmin | `phpmyadmin:latest`                         | Boodark theme, config storage auto-seeded |

## Make targets

Run bare `make` for the help menu:

| Target    | What it does |
|-----------|--------------|
| `build`   | Build (or refresh) all images — run after a Containerfile/ini change |
| `start`   | (Re)create the stack from existing images (auto-builds if missing) |
| `stop`    | Remove all containers (MySQL data survives in the volume) |
| `restart` | Same as `start` |
| `status`  | List containers |
| `shell`   | Login shell inside the PHP container |
| `logs`    | Last 20 log lines from each container |
| `check`   | Smoke-test both endpoints |
| `env`     | Create `.env` from `.env.example` |
| `clean`   | Stop everything, delete the MySQL volume and built images |

`start` runs its stages in sequence (`env-guard → mysql-up → pma-up → php-up → nginx-up`), building images first only if they're missing; each stage is also callable on its own, and guards fail with a hint if a required service isn't running.

## Configuration

All settings live in `.env` (gitignored; `make env` bootstraps it):

| Variable | Default | Purpose |
|----------|---------|---------|
| `APP_NAME` / `APP_ENV` | `app` / `dev` | Every container, image, and volume is named `$(APP_NAME)-$(APP_ENV)-*` |
| `APP_DOMAIN` | `app.localhost` | The app's domain |
| `PMA_DOMAIN` | `phpmyadmin.localhost` | phpMyAdmin's domain |
| `DB_NAME` / `DB_USER` / `DB_PASS` | `app` / `app` / `secret` | MySQL database, app user, and password (`DB_PASS` doubles as root password) |

Changing `APP_NAME` or `APP_ENV` forks the stack: new container names **and a fresh empty volume**. Run `make stop` before editing them, and clean up the old volume manually.

## Debugging with Xdebug

Xdebug runs in trigger mode on port 9003 — normal requests are full speed; debugging activates per-request via `?XDEBUG_SESSION=1` or the browser cookie (e.g. the "Xdebug helper" extension).

A VS Code launch config is included (`.vscode/launch.json`): install the **PHP Debug** extension, press F5, set a breakpoint, trigger a request. The container reaches your IDE at `192.168.64.1` (the host as seen from the container subnet) — already configured in `server/php/php.ini`.

## How it works (the non-obvious parts)

- **No inter-container DNS** in Apple container 1.0 — containers only reach each other by IP. `make start` extracts each container's IP and wires it into the next: MySQL's IP goes to PHP/phpMyAdmin as env vars, and nginx's config is *generated* from `server/nginx/default.conf.tpl` with the PHP/phpMyAdmin IPs substituted. Never edit `server/nginx/conf.d/default.conf` — edit the template.
- **Port 80 without root** — macOS allows unprivileged binds below 1024 only on the wildcard address, so nginx publishes on `0.0.0.0:80`. Consequence: the stack is reachable from your LAN, and phpMyAdmin auto-logs-in as MySQL root. **Playground use only.**
- **PHP code needs no rebuild** — `public/` is bind-mounted into both PHP-FPM and nginx. Containerfile, `php.ini`, or `mysql.cnf` changes need `make build`.
- **Reclaiming disk** — Apple container gives every image and container its own unshared rootfs, and the BuildKit builder VM only grows, so the store creeps up over time. `make start` reuses existing images (no per-run rebuild); run `make build` to refresh them, and `make clean` to reclaim everything — images, dangling layers, the builder VM, and the volume.

## Project layout

```
public/               the app (index.php, phpinfo.php) — bind-mounted
server/
  nginx/              Containerfile, default.conf.tpl (conf.d/ is generated)
  php/                Containerfile, php.ini, aliases.sh
  phpmyadmin/         Containerfile (Boodark theme)
  mysql/              Containerfile, mysql.cnf
Makefile              all orchestration
.env.example          copy to .env (via make env) and adjust
```
