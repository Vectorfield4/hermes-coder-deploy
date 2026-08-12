---
name: command-handler
description: Обрабатывает команды из Telegram, создаёт задачи в Kanban с автоматическим определением проекта
metadata:
  hermes:
    tags: [telegram, gateway, dispatcher]
---

# Command Handler

## Вход
- Сообщение из Telegram (`{{ env.TELEGRAM_MESSAGE }}`)
- ID чата (`{{ env.TELEGRAM_CHAT_ID }}`)

## Доступные команды

### 1. `/task <описание>`
Создаёт задачу для оркестратора с автоматическим определением проекта.

**Алгоритм**:
1. Извлечь описание из сообщения (всё после `/task`).
2. Если описание пустое → ответить: "Пожалуйста, укажите описание задачи."
3. Получить список проектов из памяти: memory_read(projects) Если проектов нет → `project = "default"`.
4. Сопоставить описание с проектами:
- Искать в описании ключевые слова: названия проектов, их алиасы, или слова "сайт", "проект", "репо" + контекст.
- Использовать LLM для семантического анализа: "К какому проекту относится эта задача?"
- Если найден подходящий проект → использовать его.
- Если не найден → `project = "default"`.
5. Определить тип задачи:
- Если в описании есть "bug", "fix", "ошибка" → `type = "bugfix"`
- Иначе `type = "feature"`
6. Создать задачу в Kanban: 
kanban_create(
title: "{{ description }}",
description: "{{ description }}",
assignee: orchestrator,
status: ready,
metadata: {
project: "{{ project }}",
type: "{{ type }}",
chat_id: "{{ env.TELEGRAM_CHAT_ID }}",
source: "telegram"
}
)
7. Ответить: "✅ Задача #<id> создана для проекта **{{ project }}** и передана оркестратору."

### 2. `/project add <url> [name]`
Добавляет новый проект и создаёт задачу на инициализацию **напрямую для кодера**.

**Алгоритм**:
1. Извлечь URL репозитория.
2. Если указано имя → использовать его, иначе извлечь из URL (последняя часть без `.git`).
3. Сохранить проект в память:
memory_write(projects, {
name: "{{ project_name }}",
url: "{{ url }}",
added_at: "{{ timestamp }}"
})
4. Создать задачу на инициализацию **сразу для кодера** (минуя оркестратор):
kanban_create(
title: "Initialize project {{ project_name }}",
description: "Initialize project structure, install dependencies, and set up CI",
assignee: coder,
status: ready,
metadata: {
project: "{{ project_name }}",
type: "init",
chat_id: "{{ env.TELEGRAM_CHAT_ID }}",
source: "telegram",
repo_url: "{{ url }}"
}
)
5. Ответить: "✅ Проект **{{ project_name }}** добавлен. Создана задача #<id> для инициализации (исполнитель: coder)."

### 3. `/status [id]`
Показывает статус задачи или список всех задач.

**Алгоритм**:
- Если указан ID → показать статус конкретной задачи: kanban_get_task(id) 
- Если ID не указан → показать последние 5 задач пользователя (по `chat_id` из метаданных).

### 4. `/cancel <id>`
Отменяет задачу (переводит в `cancelled`).

**Алгоритм**:
1. Проверить, что задача существует и принадлежит пользователю (по `chat_id`).
2. Если можно отменить → `kanban_update(id, status: cancelled)`.
3. Ответить: "❌ Задача #<id> отменена."

### 5. `/help`
Показывает список доступных команд.

