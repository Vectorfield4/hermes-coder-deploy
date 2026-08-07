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

## ⏰ Активация loop-навыков (cron)

Loop-навыки запускаются по расписанию через встроенный планировщик Hermes. Для этого в каждом профиле есть папка `cron/` с YAML-файлами:

- `profiles/dispatcher/cron/housekeeping-loop.yaml` — каждые 30 секунд
- `profiles/coder/cron/worker-loop.yaml` — каждые 30 секунд
- `profiles/qa/cron/qa-loop.yaml` — каждые 30 секунд

Пример `profiles/coder/cron/worker-loop.yaml`:

```yaml
schedule: "*/30 * * * * *"
skill: worker-loop
description: "Захватывает задачи в статусе ready, запускает create-pr"