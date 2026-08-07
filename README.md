# Hermes Coder Deploy

Мультиагентная система разработки на базе Hermes Agent с оркестрацией через Kanban-доску.

## 📋 Профили

| Профиль | Роль | Основные навыки |
|---------|------|-----------------|
| **dispatcher** | Приём команд из Telegram, создание задач в Kanban, отправка уведомлений, housekeeping (zombie detection) | `command-handler`, `housekeeping-loop` |
| **coder** | Анализ репозитория, генерация кода, создание Pull Request'ов | `worker-loop`, `create-pr`, `setup-ci` |
| **qa** | Проверка CI, мёрж PR, деплой на FTP, возврат задач на доработку | `qa-loop`, `review-and-deploy`, `resolve-merge-conflict`, `cleanup-branch`, `deploy-ftp` |

## 🧠 Навыки (Skills)

Каждый навык — это Markdown-инструкция для агента. Навыки лежат в `profiles/<profile>/skills/<skill-name>/SKILL.md`.

### dispatcher
- **command-handler** — обрабатывает команды `/task`, `/status`, `/cancel`, `/help` из Telegram.
- **housekeeping-loop** — каждые 30 секунд: поиск zombie-задач (heartbeat > 120 сек), возврат в ready/review, отправка уведомлений в Telegram при смене статуса.

### coder
- **worker-loop** — каждые 30 секунд: поиск задач в ready, захват, запуск `create-pr`, обновление heartbeat.
- **create-pr** — анализ репозитория, генерация кода, локальная валидация, создание ветки и PR.
- **setup-ci** — создаёт `.github/workflows/ci.yml` (однократно).

### qa
- **qa-loop** — каждые 30 секунд: поиск задач в review, захват, запуск `review-and-deploy`.
- **review-and-deploy** — проверка CI (ожидание до 10 мин), мёрж (squash), запуск деплоя.
- **resolve-merge-conflict** — автоматическое разрешение конфликтов через `git merge --strategy-option theirs`.
- **cleanup-branch** — удаление ветки `feature/hermes-<task_id>` после завершения.
- **deploy-ftp** — сборка проекта и выгрузка на FTP.

## 🛠 Скрипты

| Скрипт | Назначение |
|--------|------------|
| `make init` | Создаёт `.env` файлы для всех профилей из `.env.example` |
| `make up` | Запускает контейнеры (`docker compose up -d`) |
| `make down` | Останавливает контейнеры |
| `make logs` | Показывает логи всех контейнеров |
| `make backup` | Создаёт бэкап Kanban-доски в `backups/` |

## 🚀 Быстрый старт

```bash
git clone https://github.com/Vectorfield4/hermes-coder-deploy.git
cd hermes-coder-deploy
chmod +x scripts/*.sh
make init          # создаёт .env файлы
# отредактируйте каждый .env, вставив реальные ключи
make up            # запускает систему