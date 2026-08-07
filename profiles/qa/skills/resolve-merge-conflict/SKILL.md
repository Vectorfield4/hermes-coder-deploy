---
name: resolve-merge-conflict
description: Автоматическое разрешение конфликтов слияния.
---

# Resolve Merge Conflict

1. Переключиться на ветку PR (`feature/hermes-<task_id>`).
2. Выполнить `git fetch origin && git merge origin/<base_branch>`.
3. Если конфликтов нет – успех.
4. Если есть конфликты:
   - Попытаться автоматически разрешить через `git merge --strategy-option theirs`.
   - Если не удалось – определить конфликтующие файлы.
   - Добавить комментарий к задаче с перечнем файлов.
   - Вернуть ошибку (задача перейдёт в `ready`).
5. При успешном разрешении – выполнить `git commit` и `git push`.