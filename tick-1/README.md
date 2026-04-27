# TICK-1

Готовый набор конфигурации для домашнего задания по TICK stack поверх CMS в Docker.

## Что внутри

- `telegraf/telegraf.conf` — сбор метрик хоста, Docker, nginx, php-fpm, PostgreSQL и HTTP-проверок.
- `kapacitor/kapacitor.conf` — базовая конфигурация Kapacitor.
- `kapacitor/tasks/*.tick` — правила алертинга.
- `chronograf/resources/*.src` и `*.kap` — преднастроенные подключения Chronograf к InfluxDB и Kapacitor.
- `influxdb/init/01-create-db.iql` — создание БД `telegraf`.

## Быстрый старт

1. Скопировать `docker-compose.yml` в корень проекта.
2. Скопировать директорию `TICK-1` в корень проекта.
3. Применить пример `nginx/conf.d/default.conf`.
4. Добавить содержимое `cms/php/www.conf.append` в конфиг пула php-fpm.
5. Создать `postgres/init/01-create-telegraf-user.sql` в проекте.
6. Запустить стек: `docker compose up -d`.
7. Открыть:
   - CMS: `http://localhost:8080`
   - Chronograf: `http://localhost:8888`
   - InfluxDB API: `http://localhost:8086`
   - Kapacitor API: `http://localhost:9092`

## Какие алерты включены

- высокая загрузка CPU;
- высокая загрузка памяти;
- высокая занятость диска;
- исчезновение метрик nginx (deadman);
- недоступность CMS по HTTP / HTTP 5xx.

## Что вынести на дашборд

- CPU, RAM, disk хоста;
- CPU/RAM контейнеров Docker;
- Nginx active connections и requests;
- PHP-FPM active/idle processes и queue;
- PostgreSQL numbackends, commits, rollbacks, blks hit/read;
- время ответа и доступность главной страницы CMS.
