---
name: deploy-ftp
description: Uploads built files to an FTP host.
---

# Deploy FTP

1. Make sure the repository is up to date (`git pull`).
2. If a build is required, run the commands from `validation_commands` (e.g., `npm install && npm run build`).
3. Get FTP credentials from `.env` (FTP_HOST, FTP_USER, FTP_PASS).
4. Upload the files to FTP:
   - Use `lftp` or `curl`.
   - Example: `lftp -u $FTP_USER,$FTP_PASS $FTP_HOST -e "mirror -R ./build ./public; quit"`.
5. On success — finish.
6. On failure — return an error to move the task to `blocked`.
