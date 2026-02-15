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
