---
name: setup-ci
description: Создаёт базовый CI-пайплайн (GitHub Actions).
---

# Setup CI

Выполняется однократно при инициализации репозитория.

## Алгоритм
1. Определить тип проекта:
   - `package.json` → Node.js (npm install && npm test)
   - `requirements.txt` → Python (pip install -r requirements.txt && pytest)
   - `pom.xml` → Java (Maven)
   - иначе – общий шаблон
2. Создать `.github/workflows/ci.yml` с соответствующими шагами.
3. Закоммитить и запушить файл.
4. Добавить комментарий к задаче: "CI настроен".