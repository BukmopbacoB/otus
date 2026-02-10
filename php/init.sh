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
