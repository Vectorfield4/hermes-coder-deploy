# Hermes Coder Deploy

Мультиагентная система разработки на базе Hermes Agent с оркестрацией через Kanban-доску.

## 🐳 Сервисы

| Сервис | Профиль | Роль | Команда | Навык |
|--------|---------|------|---------|-------|
| **dispatcher** | dispatcher | `orchestrator` | `hermes kanban work --loop` | `orchestrate-task` |
| **coder** | coder | `developer` | `hermes kanban work --loop --skip_context_files` | `execute-task` |
| **qa** | qa | `qa` | `hermes kanban work --loop` | `execute-qa-task` |
| **telegram-bot** | dispatcher | — | `hermes gateway run --gateway telegram` | `command-handler` |

Все сервисы разделяют общий том `hermes-data` (Kanban + память агентов) — это единственный канал координации.

## 🧠 Навыки (Skills)

Каждый навык — это Markdown-инструкция для агента. Навыки лежат в `profiles/<profile>/skills/<skill-name>/SKILL.md`.

### dispatcher
- **command-handler** — обрабатывает команды `/task`, `/project add`, `/status`, `/cancel`, `/help` из Telegram; создаёт задачи для оркестратора (или сразу для кодера при `/project add`).
- **orchestrate-task** — декомпозирует задачу на компонентные подзадачи (UI / content / integration), координирует одну общую ветку `feature/<task_id>-<title>` и финальную задачу на создание PR.

### coder
- **execute-task** — выполняет одну компонентную подзадачу (`component: true`) или собирает изменения и создаёт PR (`pr_creation: true`).
- **create-pr** — валидация (lint/тесты), коммит, пуш ветки, создание PR.
- **project-init** / **setup-ci** — инициализация проекта (для задач `type: init`).
- **project-discover** — сканирует `/workspace`, читает контекст проекта (`AGENTS.md`, `.hermes.md` и т.д.).
- Специализированные: **ui-architect**, **ui-implementer**, **content-strategist**, **integration-specialist**, **technical-planner**, **narrative-designer**, **simple-task-executor**, **threejs-scene-builder**.

### qa
- **execute-qa-task** — выполняет задачу ревью: запускает `review-and-deploy`, при проблемах возвращает задачу кодеру (`ready`) или блокирует (`blocked`).
- **review-and-deploy** — проверка CI (ожидание до 10 мин), код-ревью, мёрж (squash), запуск деплоя.
- **resolve-merge-conflict** — автоматическое разрешение конфликтов через `git merge --strategy-option theirs`.
- **cleanup-branch** — удаление ветки после завершения.
- **deploy-ftp** — сборка проекта и выгрузка на FTP.

## 🔄 Как работают loop-процессы

Расписаний cron больше нет. Каждый worker-контейнер запускает бесконечный цикл через `hermes kanban work --profile <p> --role <r> --skill <s> --loop --interval 5` (опрос Kanban каждые 5 секунд), а Telegram-gateway работает как отдельный сервис `telegram-bot`. Вся привязка сервис → роль → навык задаётся только в `docker-compose.yml`.

**Поток задач:** `/task` в Telegram → задача `ready` для оркестратора → декомпозиция на подзадачи → кодер выполняет компоненты → PR-задача создаёт PR → QA проверяет и деплоит → `done`.

## 🚀 Развёртывание

### Вариант 1: Автоматический cloud-init (рекомендуется)

1. В панели Timeweb Cloud при создании сервера найдите поле **«Cloud-init»** (вкладка «Конфигурация»).
2. Скопируйте содержимое файла `cloud-init.sh` из репозитория и вставьте его в это поле.
3. Создайте сервер.
4. После загрузки сервера подключитесь по SSH и заполните секреты (как показано в сообщении от cloud-init).
5. Запустите систему командой `make up`.
6. Проверьте работу: `make logs`.

**Бэкап Kanban** автоматически настроен на ежедневный запуск в 02:00. При необходимости измените расписание через `crontab -e`.

## 📦 Обновление

Контейнеры устанавливают профили из этого GitHub-репозитория при старте. Для выкатки изменений:

1. `git pull` на сервере (обновляет локальный клон, из которого docker compose читает `.env`/compose/скрипты).
2. `docker compose up -d --force-recreate` — для изменений compose/скриптов или полного переустановления профилей.
3. `make update-profiles` — достаточно при изменениях только навыков (без рестарта).
