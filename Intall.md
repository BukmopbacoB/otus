# 1. Полная пересборка и запуск
## В корне проекта:
```bash
docker-compose down -v
docker-compose build --no-cache php
docker-compose up -d
docker-compose ps
```
## Должно быть:
```text
cms-nginx      Up
cms-php        Up
cms-postgres   Up
```
<!-- Если так и есть — nginx и php-fpm связаны корректно. -->

# 2. Проверка PHP и GD
```bash
docker-compose exec php php -v
docker-compose exec php php -m | grep -i gd
```
<!-- GD должен присутствовать. -->

# 3. Один раз починить Drupal-права (root внутри контейнера)
```bash
docker-compose exec -u root php sh -c '
  mkdir -p /var/www/html/sites/default/files &&
  cp -n /var/www/html/sites/default/default.settings.php /var/www/html/sites/default/settings.php &&
  chown -R www-data:www-data /var/www/html/sites/default &&
  chmod -R 755 /var/www/html/sites/default/files &&
  chmod 644 /var/www/html/sites/default/default.settings.php &&
  chmod 664 /var/www/html/sites/default/settings.php
'
```
## Проверка:
```bash
docker-compose exec php ls -la /var/www/html/sites/default/
```
<!-- Должны быть default.settings.php, settings.php, files/ с владельцем www-data. -->

# 4. Установка Drupal
## Открыть в браузере:
http://localhost:8080/core/install.php

<!-- Все requirements должны быть зелёными. -->

DB:
Тип: PostgreSQL
Хост: db
Имя: drupal
Пользователь: drupal
Пароль: drupal.

Пройти установку — сайт готов.

# 5. Что будет дальше при down / up -d
<!-- Код Drupal в ./src — не трогаем. -->

<!-- БД в volume pgdata — тоже сохраняется. -->

<!-- Права sites/default уже настроены. -->

## После этого:
```bash
docker-compose down
docker-compose up -d
```
<!-- Drupal поднимается сразу, без повторных прав/копирования файлов. -->

<!-- Сделаем простой init-скрипт, который можно запускать вручную, без изменения ENTRYPOINT (чтобы контейнер не падал). 
Этого достаточно, чтобы после docker-compose down -v одной командой всё «починить». -->

# 1. Добавляем init.sh в образ
## Создать файл php/init.sh:
```bash
mkdir -p php

cat > php/init.sh << 'EOF'
#!/bin/sh
set -e

echo "[drupal-init] Fixing sites/default permissions..."

# Если Drupal ещё не распакован — выходим тихо
if [ ! -d /var/www/html/sites/default ]; then
  echo "[drupal-init] /var/www/html/sites/default не найден, пропускаю."
  exit 0
fi

# Создаём files и settings.php при необходимости
mkdir -p /var/www/html/sites/default/files

if [ ! -f /var/www/html/sites/default/default.settings.php ]; then
  echo "[drupal-init] ВНИМАНИЕ: нет default.settings.php, проверь распаковку Drupal."
else
  if [ ! -f /var/www/html/sites/default/settings.php ]; then
    cp /var/www/html/sites/default/default.settings.php /var/www/html/sites/default/settings.php
  fi
fi

# Права для www-data
chown -R www-data:www-data /var/www/html/sites/default
chmod -R 755 /var/www/html/sites/default/files
[ -f /var/www/html/sites/default/default.settings.php ] && chmod 644 /var/www/html/sites/default/default.settings.php
[ -f /var/www/html/sites/default/settings.php ] && chmod 664 /var/www/html/sites/default/settings.php

echo "[drupal-init] Done."
EOF

chmod +x php/init.sh
```
## Обновить php/Dockerfile, добавив копирование скрипта (в конец, перед WORKDIR):
```text
FROM php:8.3-fpm-alpine

RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libpq-dev \
    git \
    unzip \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install pdo_pgsql gd

# Кладём init-скрипт в образ
COPY init.sh /usr/local/bin/drupal-init
RUN chmod +x /usr/local/bin/drupal-init

WORKDIR /var/www/html
```
<!-- ENTRYPOINT не трогаем, php-fpm остаётся как есть — контейнер будет стабильно жить. -->

## Пересобрать:
```bash
docker-compose build --no-cache php
docker-compose up -d
```
# 2. Как пользоваться init.sh после down -v
## После любого «жёсткого» сброса:
```bash
docker-compose down -v
docker-compose up -d
```
## Если Drupal снова жалуется на sites/default/files или settings.php, просто выполнить:
```bash
docker-compose exec -u root php drupal-init
```
<!-- Он:

создаст sites/default/files (если нет),

скопирует default.settings.php → settings.php (если нет),

выставит права www-data и нужные chmod. -->

## Можно прогнать (не повредит):
```bash
docker-compose exec -u root php drupal-init
```
<!-- После этого http://localhost:8080 / core/install.php будет в том же рабочем состоянии, а в проекте останется понятный способ «починить права» одной командой. -->
