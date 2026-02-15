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


# Отчёт о выполнении ДЗ GAP-2: Хранилище метрик для Prometheus
## По задаче «Хранилище метрик» сделано следующее.

1. Добавлено внешнее хранилище метрик VictoriaMetrics
  - В docker-compose.yml добавлен сервис victoriametrics на образе victoriametrics/victoria-metrics:latest.
  - Настроен параметр -retentionPeriod=2w, обеспечивающий хранение метрик за последние 2 недели.
  - Данные VictoriaMetrics складываются в отдельный том vmdata, чтобы переживать перезапуски контейнеров.

2. Настроен Prometheus на запись метрик в VictoriaMetrics (remote_write)
  - В prometheus/prometheus.yml добавлен блок remote_write с адресом http://victoriametrics:8428/api/v1/write.
  - Таким образом, Prometheus продолжает опрашивать экспортеры, но дополнительно отправляет все собранные метрики в VictoriaMetrics.

3. Добавлен автоматический лейбл site="prod" при записи в хранилище
  - В секции remote_write настроен write_relabel_configs, который добавляет ко всем сериям метку site со значением "prod".
​  - Это обеспечивает маркировку всех метрик в хранилище как относящихся к прод‑окружению.

4. Проверена работоспособность связки Prometheus → VictoriaMetrics
  - VictoriaMetrics проверена по health‑endpoint /-/healthy и по выдаче собственных метрик на /metrics.
    - curl http://localhost:8428/-/healthy
    - curl http://localhost:8428/metrics 
  - Через PromQL‑запросы к VictoriaMetrics (/api/v1/query?query=up) проверено, что метрики из Prometheus действительно принимаются и имеют добавленный лейбл site="prod".
    - curl 'http://localhost:8428/api/v1/query?query=up'
