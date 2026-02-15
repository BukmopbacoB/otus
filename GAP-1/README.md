# Отчёт о выполнении ДЗ GAP-1: Мониторинг CMS с Prometheus

## Цель задания
Установить open-source CMS с компонентами nginx + PHP-FPM + PostgreSQL,  
добавить экспортеры для сбора метрик со всех компонентов,  
настроить Prometheus для сбора метрик каждые 5 секунд.

## Что было сделано
1. Установлена CMS Drupal 10 (php:8.3-fpm-alpine)
   - nginx:1.25-alpine
   - php-fpm из кастомного Dockerfile
   - PostgreSQL 16 (с расширением pg_trgm для Drupal)

2. Собрана вся система в одном docker-compose.yml
   - CMS доступна по http://localhost:8080
   - Установка Drupal проходит полностью (профиль Standard)
   - Загруженные файлы сохраняются в ./src

3. Добавлены Prometheus-экспортеры:
   - node-exporter — метрики хоста (CPU, память, диски)
   - nginx-exporter — метрики nginx (stub_status)
   - postgres-exporter — метрики PostgreSQL
   - blackbox-exporter — проверка доступности CMS (HTTP 2xx) + TCP-порты (PostgreSQL 5432, PHP-FPM 9000)

4. Настроен Prometheus
   - scrape_interval: 5s
   - Сбор метрик со всех экспортеров
   - Данные сохраняются в volume prometheus_data
   - Доступен по http://localhost:9090

5. Персистентность данных
   - База PostgreSQL — volume pgdata
   - Файлы сайта — ./src (bind-mount)
   - При down/up без -v состояние сайта сохраняется
