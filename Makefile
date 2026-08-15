.PHONY: init up down logs backup memory-bootstrap update-profiles

init:
	bash scripts/init.sh

up:
	docker compose up -d

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