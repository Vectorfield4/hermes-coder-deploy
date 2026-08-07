---
name: cleanup-branch
description: Удаление локальной и удалённой ветки.
---

# Cleanup Branch

1. Проверить существование ветки `feature/hermes-<task_id>`.
2. Переключиться на другую ветку (например, `main`).
3. Удалить локальную ветку: `git branch -d feature/hermes-<task_id>`.
4. Удалить удалённую ветку: `git push origin --delete feature/hermes-<task_id>`.
5. Добавить комментарий к задаче: "Ветка удалена".