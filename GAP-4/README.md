# Отчёт о выполнении ДЗ GAP-4: Формирование dashboard
## По задаче «Формирование dashboard на основе собранных данных с Grafana» сделано следующее

1. Grafana последней версии добавлена в `docker-compose.yml` как отдельный сервис, данные сохраняются в volume `grafana_data`. Интерфейс доступен на `http://localhost:3000.`

2. В Grafana настроен Data source Prometheus (`http://prometheus:9090`).

3. Созданы две папки: infra и app.

4. В папке `infra` создан дашборд `Infrastructure` со следующими панелями:
  - CPU usage (`node_cpu_seconds_total`)
  - RAM usage (`node_memory_MemAvailable_bytes`)
  - Network In/Out (`node_network_receive`/`transmit_bytes_total`) — входящий трафик вверх, исходящий вниз
  - Disk Operations Speed (`node_disk_read_bytes_total`/`node_disk_written_bytes_total`) — Суммарный объём данных, прочитанных с диска вверх, суммарный объём данных, записанных на диск вниз

5. В папке `app` создан дашборд `CMS metrics` со следующими панелями:
  - Доступность сайта Drupal (`probe_success`)
  - Время ответа HTTP (`probe_duration_seconds`)
  - Среднее количество HTTP-запросов в секунду за последние 5 минут (`nginx_http_requests_total`)
  - Текущий размер базы данных drupal в байтах (`pg_database_size_bytes`)

6. Создан алерт в Grafana на высокую загрузку CPU (> 90%) с привязкой к папке `infra` и настроенным contact point для отправки уведомлений.

7. Drill-down дашборд
  - Создан детальный дашборд `infra-detail` в папке `infra` с переменной `$instance`. Переменная позволяет переключаться между инстансами через выпадающий список.
  - В дашборде `infra-detail` созданы панели с фильтрацией по `$instance`:
    - CPU usage
    - RAM usage
    - Network In/Out
  - В сводном дашборде `Infrastructure` на панели CPU usage настроена ссылка Data link ("Подробнее") с URL вида `/d/<UID>/infra-detail?var-instance=${__field.labels.instance}`.
  - При клике на любую точку графика CPU в `Infrastructure` открывается дашборд `infra-detail` с автоматически подставленным значением instance — отображается детальная информация именно по выбранному узлу.
