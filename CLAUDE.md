# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native-PHP sample stack (nginx + PHP-FPM + MySQL + phpMyAdmin) running on **Apple's `container` CLI** — not Docker. Everything is orchestrated by the Makefile; there is no docker-compose. The app itself is a single PDO page at `public/index.php`.

## Commands

- `make` — help menu (default target)
- `make start` — build images and (re)create the whole stack; always recreates containers from scratch
- `make stop` — remove all containers (MySQL data survives in the named volume)
- `make check` — verify both endpoints respond (app + phpMyAdmin); run this after changes
- `make shell` — login shell in the PHP container (loads `server/php/aliases.sh`)
- `make logs` / `make status` — diagnostics
- `make clean` — also deletes the MySQL volume and built images

Configuration lives in `.env` (gitignored but **required** — generate it with `make env`, which copies `.env.example`). All container/image/volume names derive from `$(APP_NAME)-$(APP_ENV)`.

URLs: `http://$(APP_DOMAIN)` (app) and `http://$(PMA_DOMAIN)` (phpMyAdmin). Any `*.localhost` name resolves to loopback on macOS natively — no /etc/hosts entries needed.

## Architecture — the non-obvious parts

**Apple container has no inter-container DNS** (verified on 1.0.0: containers get hostnames but resolving them returns NXDOMAIN). Containers only reach each other by IP on 192.168.64.0/24. The Makefile therefore wires IPs at start time: it starts mysql, extracts its IP from `container ls` (the `ip` macro), passes it as env to the fpm/pma containers, then generates the nginx config.

**`server/nginx/conf.d/default.conf` is generated — never edit it.** Edit `server/nginx/default.conf.tpl` instead; `make start` substitutes `__PHP_IP__`, `__PMA_IP__`, `__APP_DOMAIN__`, `__PMA_DOMAIN__` via sed. The generated dir is gitignored.

**Startup order in `make start` matters**: db → TCP-ping wait → pma → config-storage seed → fpm → nginx conf generation → web. The MySQL wait uses `mysqladmin ping --protocol=TCP` deliberately — during first-boot initialization MySQL answers socket pings while TCP is still down, so a plain ping releases the wait too early.

**One nginx fronts both domains on host port 80.** Only one process can bind :80, so phpMyAdmin is a proxy block in the same nginx, pointed at the pma container IP. Port 80 is published on 0.0.0.0 because macOS allows unprivileged low-port binds *only* on the wildcard address (specific IPs like 127.0.0.1 require root, which Apple's apiserver won't do). Consequence: the stack is reachable from the LAN, and phpMyAdmin auto-logs-in as MySQL root — playground-only setup.

**Changing `APP_NAME` or `APP_ENV` forks the stack**: new container names *and a new empty volume*; the old set becomes orphaned and the old nginx container keeps holding port 80. Run `make stop` before editing those values, then clean up the old volume manually.

**PHP code needs no rebuild** — `public/` is bind-mounted into both fpm and nginx. Containerfile or `server/php/php.ini` changes need `make start` (rebuild). `server/php/aliases.sh` is bind-mounted too; edits apply on the next login shell.

**Xdebug** is trigger-mode (`?XDEBUG_SESSION=1`), port 9003, `client_host=192.168.64.1` — the subnet gateway, i.e. the Mac as seen from inside a container. IDE path mapping: `public/` → `/var/www/html/public`.

**phpMyAdmin config storage** (`phpmyadmin` db, `pma__*` tables) is seeded on every `make start` from the image's bundled `create_tables.sql`; the schema is `IF NOT EXISTS`-idempotent, so this is a no-op on existing volumes.
