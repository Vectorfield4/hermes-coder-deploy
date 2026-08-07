---
name: deploy-ftp
description: Выгрузка собранных файлов на FTP-хостинг.
---

# Deploy FTP

1. Убедиться, что репозиторий актуален (`git pull`).
2. Если требуется сборка – выполнить команды из `validation_commands` (например, `npm install && npm run build`).
3. Определить FTP-учётные данные из `.env` (FTP_HOST, FTP_USER, FTP_PASS).
4. Загрузить файлы на FTP:
   - Использовать `lftp` или `curl`.
   - Пример: `lftp -u $FTP_USER,$FTP_PASS $FTP_HOST -e "mirror -R ./build ./public; quit"`.
5. При успехе – завершить.
6. При ошибке – вернуть ошибку для перевода задачи в `blocked`.