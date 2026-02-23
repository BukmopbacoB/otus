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
