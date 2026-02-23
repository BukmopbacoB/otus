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


# Отчёт о выполнении ДЗ GAP-3: Настройка алертинга
## По задаче «Настройка алертинга» сделано следующее.

1. Развернут Alertmanager и интегрирован с Prometheus
  - добавлен файл правил prometheus/rules/alerts.yml с WARNING/CRITICAL‑алертами по нагрузке CPU и доступности Drupal.
​
2. Настроены маршруты Alertmanager: 
  - системные алерты отправляются в Telegram‑чат, 
  - критические — через webhook‑бота в Telegram, 
  - предупреждения — на почту Gmail.
​
3. Реализована отправка писем через SMTP Gmail (через App Password), 
  - все логины и пароли вынесены в .env и подтягиваются в alertmanager.yml через подстановку переменных.
​
4. Добавлен сервис alertmanager-telegram (webhook‑relay) и настроен Alertmanager на отправку критических уведомлений на URL этого сервиса внутри Docker‑сети.
​
5. Для скрытия секретов реализован шаблон alertmanager.yml.tmpl и стартовый скрипт (через entrypoint в docker-compose.yml), который при запуске контейнера подставляет значения из .env и генерирует итоговый конфиг Alertmanager.

6. Работоспособность алертинга проверена вручную отправкой тестовых алертов в Alertmanager через HTTP‑API: 
  - с хоста выполнялись команды curl на http://localhost:9093/api/v2/alerts с телом status: firing и status: resolved, после чего подтверждено получение уведомлений в Telegram и по email
  ```bash
    curl -X POST -H "Content-Type: application/json"   -d '[{
            "status": "firing",
            "labels": {
              "alertname": "TestTelegramAlert",
              "severity": "system"
            },
            "annotations": {
              "summary": "Test alert via native Telegram",
              "description": "This is a test alert sent via curl"
            }
          }]'   http://localhost:9093/api/v2/alerts
  ```

  ```bash
    curl -X POST -H "Content-Type: application/json"   -d '[{
            "status": "firing",
            "labels": {
              "alertname": "TestWebhookTelegramAlert",
              "severity": "critical"
            },
            "annotations": {
              "summary": "Test alert via the webhook-bot to Telegram",
              "description": "This is a test alert sent via curl"
            }
          }]'   http://localhost:9093/api/v2/alerts
  ```

```bash
    curl -X POST -H "Content-Type: application/json"   -d '[{
            "status": "firing",
            "labels": {
              "alertname": "TestEMailAlert",
              "severity": "warning"
            },
            "annotations": {
              "summary": "Test alert to Gmail",
              "description": "This is a test alert sent via curl"
            }
          }]'   http://localhost:9093/api/v2/alerts
```
