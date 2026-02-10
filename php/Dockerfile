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
