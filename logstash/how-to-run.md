# Как запускать стенд
## 1. Поднять приложение (источники логов)
```bash
docker compose -f compose.core.yml up -d
```

Проверка:
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
# должны быть cms-nginx, cms-php, cms-postgres
```

## 2. Вариант A. Logstash‑пайплайн
### 2.1. Поднять Elasticsearch, Kibana, Heartbeat и Logstash:

```bash
docker compose -f compose.elk.logstash.yml up -d
```

### 2.2. Поднять Beats, отправляющие логи в Logstash:

```bash
docker compose -f compose.beats.logstash.yml up -d
```

### 2.3. Проверка:

```bash
curl -u elastic:${ELASTIC_PASSWORD} http://localhost:9200/_cat/indices?v
# должен появиться индекс/alias logs-app*
```

В Kibana (http://localhost:5601) в Discover выбрать Data View на logs-app* и убедиться, что есть поля nginx.* и php_fpm.*.

## 3. Вариант B. Vector‑пайплайн
### 3.1. Поднять Elasticsearch, Kibana, Heartbeat и Vector:

```bash
docker compose -f compose.elk.vector.yml up -d
```

### 3.2. Сгенерировать немного трафика:

```bash
for i in {1..10}; do
  curl -s http://localhost:8080/index.php >/dev/null
  sleep 1
done
```

### 3.3. Проверка:

```bash
curl -u elastic:${ELASTIC_PASSWORD} http://localhost:9200/_cat/indices?v
# индекс вида vector-logs-YYYY.MM.DD

curl -u elastic:${ELASTIC_PASSWORD} \
  'http://localhost:9200/vector-logs-*/_search?pretty&size=5&q=log_type:nginx'
curl -u elastic:${ELASTIC_PASSWORD} \
  'http://localhost:9200/vector-logs-*/_search?pretty&size=5&sort=timestamp:desc&q=log_type:php_fpm'
```

В Kibana (Data View vector-logs-*) — видеть поля nginx.* и php_fpm.*.

## 4. Переключение стеков
- Остановить Logstash‑вариант:

```bash
docker compose -f compose.beats.logstash.yml down
docker compose -f compose.elk.logstash.yml down
```

- Включить Vector‑вариант:

```bash
docker compose -f compose.elk.vector.yml up -d
```

Вернуться к Logstash — наоборот: down для Vector‑файла, up для compose.elk.logstash.yml и compose.beats.logstash.yml.
