ENV_FILE ?= .env
-include $(ENV_FILE)
export $(shell test -f $(ENV_FILE) && grep -v '^\#' $(ENV_FILE) | grep -v '^$$' | sed 's/=.*//')

# ponytail: nginx publishes on 0.0.0.0:80 — macOS allows ports <1024 unprivileged
# only on the wildcard address, so the bare domain works, but the app is LAN-visible.
PREFIX  := $(APP_NAME)-$(APP_ENV)
PHP_IMG := $(PREFIX)-php
PMA_IMG := $(PREFIX)-phpmyadmin

NGINX   := $(PREFIX)-nginx
PHP     := $(PREFIX)-php
PMA     := $(PREFIX)-pma
MYSQL   := $(PREFIX)-mysql

MYSQL_VOLUME := $(MYSQL)-volume

# ponytail: Apple container 1.0 has no inter-container DNS — wire IPs at start.
# Pulls the IP column out of `container ls` for a given container name.
ip = container ls | awk '$$1 == "$(1)" { sub("/.*", "", $$6); print $$6 }'

.PHONY: help env start stop restart status shell logs check clean
.DEFAULT_GOAL := help

help: ## Show this help menu
	@printf "\n\033[1;33m$(APP_NAME) ($(APP_ENV)) — PHP + nginx + MySQL on Apple container — http://$(APP_DOMAIN)\033[0m\n\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

env: ## Create .env from .env.example (won't overwrite an existing one)
	@test -f $(ENV_FILE) && echo "$(ENV_FILE) already exists — not touching it" \
		|| (cp .env.example $(ENV_FILE) && echo "Created $(ENV_FILE) from .env.example — adjust values as needed")

start: stop ## Build images and (re)create the whole stack
	@test -f $(ENV_FILE) || { echo "Missing $(ENV_FILE) — run: make env"; exit 1; }
	@container system start >/dev/null 2>&1 || true
	container build -t $(PHP_IMG) server/php
	container build -t $(PMA_IMG) server/phpmyadmin
	@container volume create $(MYSQL_VOLUME) >/dev/null 2>&1 || true
	container run -d --name $(MYSQL) \
		-v $(MYSQL_VOLUME):/var/lib/mysql \
		-e MYSQL_ROOT_PASSWORD=$(DB_PASS) \
		-e MYSQL_DATABASE=$(DB_NAME) \
		-e MYSQL_USER=$(DB_USER) \
		-e MYSQL_PASSWORD=$(DB_PASS) \
		mysql:9 --default-time-zone=+00:00
	@printf 'Waiting for MySQL '; until container exec $(MYSQL) mysqladmin ping --protocol=TCP --silent >/dev/null 2>&1; do printf .; sleep 1; done; echo ' up'
	container run -d --name $(PMA) \
		-e PMA_HOST=$$($(call ip,$(MYSQL))) \
		-e PMA_PORT=3306 \
		-e PMA_USER=root \
		-e PMA_PASSWORD=$(DB_PASS) \
		-e PMA_PMADB=phpmyadmin \
		-e PMA_CONTROLHOST=$$($(call ip,$(MYSQL))) \
		-e PMA_CONTROLPORT=3306 \
		-e PMA_CONTROLUSER=root \
		-e PMA_CONTROLPASS=$(DB_PASS) \
		$(PMA_IMG)
	@container exec $(PMA) cat /var/www/html/sql/create_tables.sql | container exec -i $(MYSQL) mysql -uroot -p$(DB_PASS) 2>/dev/null || true
	container run -d --name $(PHP) \
		-v $(PWD)/public:/var/www/html/public \
		-v $(PWD)/server/php/aliases.sh:/etc/profile.d/aliases.sh \
		-e DB_HOST=$$($(call ip,$(MYSQL))) \
		-e DB_NAME=$(DB_NAME) \
		-e DB_USER=$(DB_USER) \
		-e DB_PASS=$(DB_PASS) \
		$(PHP_IMG)
	@mkdir -p server/nginx/conf.d && sed \
		-e "s/__PHP_IP__/$$($(call ip,$(PHP)))/" \
		-e "s/__PMA_IP__/$$($(call ip,$(PMA)))/" \
		-e "s/__APP_DOMAIN__/$(APP_DOMAIN)/" \
		-e "s/__PMA_DOMAIN__/$(PMA_DOMAIN)/" \
		server/nginx/default.conf.tpl > server/nginx/conf.d/default.conf
	container run -d --name $(NGINX) \
		-p 80:80 \
		-v $(PWD)/server/nginx/conf.d:/etc/nginx/conf.d \
		-v $(PWD)/public:/var/www/html/public \
		nginx:1-alpine
	@echo "→ http://$(APP_DOMAIN)  |  http://$(PMA_DOMAIN)"

stop: ## Stop and remove all containers (MySQL data survives in the volume)
	-@for c in $(NGINX) $(PHP) $(PMA) $(MYSQL); do container rm -f $$c >/dev/null 2>&1 && echo "removed $$c"; done; true

restart: start ## Same as start

status: ## List containers
	container ls --all

shell: ## Open a login shell inside the PHP container
	container exec -it $(PHP) sh -l

logs: ## Show last 20 log lines from each container
	@for c in $(NGINX) $(PHP) $(PMA) $(MYSQL); do echo "== $$c =="; container logs $$c 2>&1 | tail -20; done

check: ## Verify the app and phpMyAdmin respond
	curl -fsS http://$(APP_DOMAIN)/ | grep -o 'Visits: [0-9]*'
	@curl -fsS -o /dev/null -w "phpMyAdmin: HTTP %{http_code}\n" http://$(PMA_DOMAIN)/

clean: stop ## Stop everything, then delete the MySQL volume and built images
	-container volume rm $(MYSQL_VOLUME)
	-container image rm $(PHP_IMG)
	-container image rm $(PMA_IMG)
