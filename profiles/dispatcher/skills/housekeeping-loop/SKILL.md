---
name: housekeeping-loop
description: Фоновое обслуживание Kanban: zombie detection, reclaim, уведомления.
---

# Housekeeping Loop

Выполняется каждые 30 секунд. Состоит из двух частей.

## Инструменты
- `kanban_list`
- `kanban_update`
- `telegram_send_message`

## 1. Zombie detection
- Получить задачи в статусах `coding` и `qa`.
- Если `heartbeat_at` старше 120 секунд:
  - `coding` → `ready` (увеличить `retry_count`)
  - `qa` → `review` (увеличить `retry_count`)
  - При `retry_count >= 3` → `blocked` с комментарием "Превышено количество попыток"

## 2. Уведомления
- Получить задачи с `chat_id` и не в терминальных статусах.
- Сравнить текущий статус с сохранённым в памяти навыка (`last_known_status`).
- Отправить уведомления при переходах:
  - `ready → coding` → "Задача #<id> взята в разработку"
  - `coding → review` → "Задача #<id>: PR создан, проверяется"
  - `review → done` → "Задача #<id> выполнена и развёрнута"
  - Любой переход в `blocked` → "Задача #<id> заблокирована: <error_message>"
  - `qa → ready` → "Задача #<id> вернулась на доработку"

**Оптимизация**: один вызов `kanban_list` за цикл, без использования LLM.