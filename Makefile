.PHONY: init up down logs backup

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

update-profiles:
	docker compose exec dispatcher hermes profile update dispatcher
	docker compose exec coder hermes profile update coder
	docker compose exec qa hermes profile update qa