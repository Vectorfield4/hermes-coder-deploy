---
name: review-and-deploy
description: Проверка CI, мёрж PR, деплой на FTP.
---

# Review and Deploy

## 1. Получение PR
- Извлечь номер PR из комментария к задаче.
- Если не найден – найти через `gh pr list` по ветке `feature/hermes-<task_id>`.

## 2. Проверка CI
- Выполнять `gh pr view <pr> --json statusCheckRollup` каждые 30 секунд.
- Максимальное ожидание – 10 минут.
- Если CI завершился с ошибкой → перевести в `ready` с логом ошибок, увеличить `cycle_count`.
- Если CI не завершился за 10 минут → `blocked` с таймаутом.

## 3. Мерж
- `gh pr merge --squash --delete-branch`.
- При конфликте → вызвать `resolve-merge-conflict`.
- Если не удалось разрешить → перевести в `ready` с комментарием "Merge conflict, please resolve".

## 4. Деплой
- Запустить навык `deploy-ftp`.
- Успех → `done` с комментарием "Развёрнуто".
- Ошибка → `blocked` с комментарием об ошибке.

## 5. Очистка
- Вызвать `cleanup-branch` (если ветка не удалена при мерже).