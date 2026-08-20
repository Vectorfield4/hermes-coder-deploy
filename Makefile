.PHONY: init up down logs backup memory-bootstrap update-profiles check-secrets daily-stats setup restart

init:
	bash scripts/init.sh

check-secrets:
	bash scripts/check-secrets.sh

up:
	bash scripts/check-secrets.sh && docker compose up -d

restart:
	docker compose up -d --force-recreate dispatcher coder qa telegram-bot

setup:
	bash scripts/check-secrets.sh
	docker compose up -d memory-db embedding dense-mem
	bash scripts/memory-bootstrap.sh
	docker compose up -d --force-recreate dispatcher coder qa telegram-bot

down:
	docker compose down

logs:
	docker compose logs -f

backup:
	bash scripts/backup.sh

memory-bootstrap:
	bash scripts/memory-bootstrap.sh

update-profiles:
	docker compose exec dispatcher hermes profile update dispatcher
	docker compose exec coder hermes profile update coder
	docker compose exec qa hermes profile update qa

daily-stats:
	bash scripts/daily-stats.sh
