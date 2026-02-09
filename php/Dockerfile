FROM php:8.3-fpm-alpine

# Установка зависимостей для GD и Postgres
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libpq-dev \
    git \
    unzip

# Конфигурация и установка расширений
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
 && docker-php-ext-install -j$(nproc) \
    pdo_pgsql \
    gd

WORKDIR /var/www/html
