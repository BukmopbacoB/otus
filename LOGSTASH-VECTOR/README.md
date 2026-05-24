# Преобразование входящих сообщений с помощью Logstash и Vector

## 1. Стенд
В работе использовался стенд из предыдущего ДЗ на базе Docker‑compose:
- `compose.core.yml` — приложение и источники логов:
  - cms-nginx (Nginx) с логами в ./logs/nginx.
  - cms-php (php-fpm) с логами в ./logs/php-fpm.
  - cms-postgres (PostgreSQL) c логами в ./logs/postgresql.

Общая сеть cms-shared-net для всех сервисов.

Поверх него поднимались разные связки для обработки логов.

## 2. Logstash‑вариант
### 2.1. Поднятые сервисы

- `compose.elk.logstash.yml`:
  - elasticsearch:8.19.4 (single‑node, ELASTIC_PASSWORD).
  - kibana:8.19.4 (ELASTICSEARCH_HOSTS=http://elasticsearch:9200, kibana_system).
  - heartbeat:8.19.4 — проверяет доступность Nginx и Kibana.
  - logstash:8.19.4 — парсинг логов и отправка в Elasticsearch.

- `compose.beats.logstash.yml`:
  - filebeat:8.19.4 и metricbeat:8.19.4 в сети cms-shared-net.

### 2.2. Filebeat → Logstash
В каталоге beats/filebeat/ два конфига:

- `filebeat.to-logstash.yml` — Filebeat читает логи из:

  - /logs/nginx/*.log
  - /logs/php-fpm/*.log
  - /logs/postgresql/*.log

и добавляет поля:

```text
fields:
  service_name: nginx|php-fpm|postgresql
  log_type: nginx|php_fpm|postgresql
fields_under_root: true
```

Отправка в Logstash:

```text
output.logstash:
  hosts: ["logstash:5044"]
```

- `filebeat.to-elasticsearch.yml` — базовый конфиг для прямой отправки в Elasticsearch (оставлен для сравнения и быстрого отката).

### 2.3. Конфигурация Logstash

- `logstash/config/logstash.yml`:
  - dead_letter_queue.enable: true
  - path.dead_letter_queue: /usr/share/logstash/data/dead_letter_queue
  - path.data вынесен на docker volume logstash_data, чтобы DLQ не терялась при перезапуске.

- `logstash/pipeline/logstash.conf`:
  - input { beats { port => 5044 } }
  - filter ветвится по полю log_type:
    - nginx (log_type == "nginx"):
      - grok парсит access‑строку в поля nginx.remote_addr, nginx.method, nginx.request, nginx.status, nginx.body_bytes_sent, nginx.http_referer, nginx.http_user_agent.
      - date настраивает @timestamp по nginx.time_local.
    - php-fpm (log_type == "php_fpm"):
      - grok под формат access‑логов php‑fpm с полями php_fpm.remote_addr, php_fpm.time_local, php_fpm.method, php_fpm.request, php_fpm.status, php_fpm.request_time, php_fpm.memory, php_fpm.cpu.
      - mutate добавляет event.dataset = "php-fpm.access".
    - postgresql (log_type == "postgresql"):
      - подготовлена ветка с grok и date для ISO8601‑логов Postgres, но в текущей версии стенда лог‑файлы Postgres ещё не включены, поэтому событий этого типа нет.
  - output:

    ```text
    elasticsearch {
      hosts => ["http://elasticsearch:9200"]
      user => "elastic"
      password => "${ELASTIC_PASSWORD}"
      ilm_enabled => true
      ilm_rollover_alias => "logs-app"
      ilm_pattern => "000001"
      ilm_policy => "logs-app-policy"
    }
    ```

    плюс stdout { codec => rubydebug } для отладки.

### 2.4. ILM

Через Kibana Dev Tools создана ILM‑политика logs-app-policy:
  - rollover в hot‑фазе по max_size: 5gb или max_age: 7d
  - delete‑фаза через 30d.

Эту политику использует Logstash‑output.

### 2.5. Скриншоты для Logstash
Discover по индексу/alias logs-app*:
  - фильтр log_type: nginx — видно поля nginx.remote_addr, nginx.method, nginx.status.
  - фильтр log_type: php_fpm — происходит ошибка парсинга и поля php_fpm.status, php_fpm.request_time, php_fpm.cpu не отображаются

## 3. Vector‑вариант
### 3.1. Поднятые сервисы

`compose.elk.vector.yml`:
  - тот же elasticsearch, kibana, heartbeat, что и в варианте с Logstash;
  - плюс контейнер vector:0.43.1-alpine, которому примонтированы каталоги с логами:
    - `./logs/nginx:/logs/nginx:ro`
    - `./logs/php-fpm:/logs/php-fpm:ro`
    - `./logs/postgresql:/logs/postgresql:ro`

Filebeat в этом варианте для логов не используется — Vector читает файлы напрямую.

### 3.2. Источники и VRL‑парсинг в Vector

`vector/vector.yaml`:
  - sources:

```yml
sources:
  nginx_logs:
    type: file
    include: ["/logs/nginx/*.log"]
    read_from: beginning

  php_fpm_logs:
    type: file
    include: ["/logs/php-fpm/*.log"]
    read_from: beginning

  postgresql_logs:
    type: file
    include: ["/logs/postgresql/*.log"]
    read_from: beginning
```

- transforms:
  - parse_nginx — parse_regex для Nginx access:
    - поля nginx.remote_addr, nginx.remote_user, nginx.time_local, nginx.method, nginx.request, nginx.http_version, nginx.status, nginx.body_bytes_sent, nginx.http_referer, nginx.http_user_agent.
    - status и body_bytes_sent приводятся к числам.
    - event.dataset = "nginx.access".
  - parse_php_fpm — parse_regex под access‑формат php‑fpm:
    - пример строки:
      - 172.18.0.4 - 18/May/2026:14:23:45 +0000 "GET /index.php" 200 13.553 2048 0.00%.
    - Regex вытаскивает remote_addr, time_local, method, request, status, request_time, memory, cpu в объект php_fpm.*.
    - status, memory — int, request_time, cpu — float.
    - event.dataset = "php-fpm.access".
  - parse_postgresql — заготовка под ISO8601‑лог, пока без реальных событий (см. выше).

При ошибке парсинга добавляется тег _vrl_parse_failure_*, по которому можно отлавливать проблемные строки.

- sink:

```text
sinks:
  elasticsearch_logs:
    type: elasticsearch
    inputs: ["parse_nginx", "parse_php_fpm", "parse_postgresql"]
    endpoints: ["http://elasticsearch:9200"]
    api_version: v8
    mode: bulk
    bulk:
      index: "vector-logs-%Y.%m.%d"
    auth:
      strategy: basic
      user: elastic
      password: "${ELASTIC_PASSWORD}"
```

Vector пишет в индекс vector-logs-YYYY.MM.DD.

### 3.3. Проверка работы Vector
- В логах Vector после старта видно:
  - запуск file sources для `/logs/nginx/*.log` и `/logs/php-fpm/*.log`;
  - сначала `connection refused` к Elasticsearch, затем `Endpoint is healthy` после его подъёма.
- В Elasticsearch через _cat/indices видно индекс vector-logs-2026.05.18.
- `/_search` по `log_type: nginx` и `log_type: php_fpm` возвращает документы с распарсенными полями `nginx.*` и `php_fpm.*`.

### 3.4. Скриншоты для Vector
- Discover → Data view `vector-logs-*`:
  - список полей содержит `log_type`, `service_name`, `message`, `nginx.*`, `php_fpm.*`, `timestamp` и др.;
  - фильтр `log_type: nginx` — видны поля `nginx.remote_addr`, `nginx.method`, `nginx.status`.
  - фильтр `log_type: php_fpm` — видны поля `php_fpm.status`, `php_fpm.request_time`, `php_fpm.cpu`, `php_fpm.memory`.

Для отчёта приложены скриншоты Discover с этими фильтрами.

## 4. Dead Letter Queue (DLQ) в Logstash
- В logstash.yml включён DLQ:
```yml
dead_letter_queue.enable: true
path.dead_letter_queue: /usr/share/logstash/data/dead_letter_queue
```
- path.data смонтирован в volume logstash_data, чтобы DLQ переживал перезапуски контейнера.
- Ошибки парсинга (например, _grokparsefailure_php_fpm) попадают в DLQ и могут быть проанализированы отдельно.

## 5. Политики ILM в Logstash → Elasticsearch
- Через Dev Tools создана ILM‑политика logs-app-policy (hot + delete‑фазы).
- Output Logstash настроен на использование ilm_enabled => true, ilm_rollover_alias => "logs-app", ilm_policy => "logs-app-policy", за счёт чего новый индекс создаётся как data stream / rollover‑структура с алиасом.