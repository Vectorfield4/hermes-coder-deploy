#!/bin/sh

# Обновление системы
apt -y update
apt -y upgrade

# Установка Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker root

# Установка Git и Make
apt -y install git make

# Клонирование репозитория
cd /root
git clone https://github.com/Vectorfield4/hermes-coder-deploy.git
cd hermes-coder-deploy

# Создание .env файлов из шаблонов
make init