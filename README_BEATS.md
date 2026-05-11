# Домашнее задание: Установка и настройка Beats

## Цель

Научиться отправлять логи и метрики с помощью Beats (Filebeat, Metricbeat, Heartbeat) в Elasticsearch и визуализировать их в Kibana.

> **Примечание о названии:** В тексте задания фигурирует слово `hearthbeat` — это **опечатка**. Правильное название продукта Elastic — **`heartbeat`** (без буквы `h` после `heart`). Именно так называется Docker-образ (`docker.elastic.co/beats/heartbeat`), конфигурационный файл (`heartbeat.yml`) и сам бинарник.

---

## Стек

| Компонент      | Роль                                      |
|----------------|-------------------------------------------|
| nginx          | Веб-сервер CMS                            |
| php-fpm        | PHP-процессор                             |
| PostgreSQL     | База данных CMS                           |
| Filebeat       | Сбор логов nginx, php-fpm, PostgreSQL     |
| Metricbeat     | Сбор метрик системы, nginx, PostgreSQL    |
| Heartbeat      | Проверка доступности HTTP и TCP           |
| Elasticsearch  | Хранение и индексация данных              |
| Kibana         | Визуализация                              |

Все сервисы объединены в сеть `cms-shared-net`.

---

## Структура репозитория
```
  .
  ├── compose.cms.yml   # CMS: nginx, php-fpm, postgres
  ├── compose.beats.yml # Beats: filebeat, metricbeat, heartbeat
  ├── compose.elk.yml   # ELK: elasticsearch, kibana
  ├── beats/
  │ ├── filebeat/
  │ │ └── filebeat.yml
  │ ├── metricbeat/
  │ │ ├── metricbeat.yml
  │ │ └── modules.d/
  │ │ ├── system.yml
  │ │ ├── nginx.yml
  │ │ └── postgresql.yml
  │ └── heartbeat/
  │ └── heartbeat.yml
  ├── postgres/
  │ └── postgresql.beats.conf
  ├── nginx/
  │ └── nginx.conf
  └── logs/
  ├── nginx/
  ├── php-fpm/
  └── postgresql/
```

---

## Конфигурации Beats

### filebeat.yml
[filebeat.yml](beats/filebeat/filebeat.yml)

### metricbeat.yml
[metricbeat.yml](beats/metricbeat/metricbeat.yml)


### heartbeat.yml
[heartbeat.yml](beats/heartbeat/heartbeat.yml)

---

## ILM-политики

Политики созданы через Elasticsearch API:

```bash
# nginx — 30 дней
curl -u elastic:$ELASTIC_PASSWORD -X PUT \
  "http://localhost:9200/_ilm/policy/logs-nginx-30d" \
  -H 'Content-Type: application/json' -d '{
    "policy": {
      "phases": {
        "hot":    { "min_age": "0ms", "actions": { "rollover": { "max_age": "1d" } } },
        "delete": { "min_age": "30d", "actions": { "delete": {} } }
      }
    }
  }'

# postgresql — 30 дней
curl -u elastic:$ELASTIC_PASSWORD -X PUT \
  "http://localhost:9200/_ilm/policy/logs-postgresql-30d" \
  -H 'Content-Type: application/json' -d '{
    "policy": {
      "phases": {
        "hot":    { "min_age": "0ms", "actions": { "rollover": { "max_age": "1d" } } },
        "delete": { "min_age": "30d", "actions": { "delete": {} } }
      }
    }
  }'

# php-fpm — 14 дней
curl -u elastic:$ELASTIC_PASSWORD -X PUT \
  "http://localhost:9200/_ilm/policy/logs-phpfpm-14d" \
  -H 'Content-Type: application/json' -d '{
    "policy": {
      "phases": {
        "hot":    { "min_age": "0ms", "actions": { "rollover": { "max_age": "1d" } } },
        "delete": { "min_age": "14d", "actions": { "delete": {} } }
      }
    }
  }'
```

---

## Запуск

```bash
# 1. Создать сеть
docker network create cms-shared-net

# 2. Поднять CMS
docker compose -f compose.cms.yml up -d

# 3. Поднять ELK
docker compose -f compose.elk.yml up -d

# 4. Установить пароль для kibana_system (после первого старта ES)
curl -u elastic:$ELASTIC_PASSWORD -X POST \
  "http://localhost:9200/_security/user/kibana_system/_password" \
  -H 'Content-Type: application/json' \
  -d '{"password":"'"$KIBANA_SYSTEM_PASSWORD"'"}'

# 5. Поднять Beats
docker compose -f compose.beats.yml up -d
```

---

## Результаты в Kibana

### Данные в Discover

| Data View       | Фильтр                        | Документы |
|-----------------|-------------------------------|------------|
| `filebeat-*`    | `log_type: nginx_access`      | ✅        |
| `filebeat-*`    | `log_type: php-fpm`           | ✅        |
| `filebeat-*`    | `event.module: postgresql`    | ✅        |
| `metricbeat-*`  | `event.module: system`        | ✅        |
| `metricbeat-*`  | `event.module: nginx`         | ✅        |
| `metricbeat-*`  | `event.module: postgresql`    | ✅        |
| `heartbeat-*`   | `monitor.status: up`          | ✅ (оба монитора) |

### ILM-политики

| Политика             | Удаление через |
|----------------------|----------------|
| `logs-nginx-30d`     | 30 дней        |
| `logs-postgresql-30d`| 30 дней        |
| `logs-phpfpm-14d`    | 14 дней        |

---

## Известные особенности

- **`hearthbeat` в задании — опечатка.** Продукт называется `heartbeat`.
- PostgreSQL должен иметь `listen_addresses = '*'` в конфиге, иначе Metricbeat не подключится.
- Директория `/var/log/postgresql` внутри контейнера должна принадлежать UID 999 (`chmod 750`, `chown 999:999`).
- Beats должны находиться в той же Docker-сети, что и Elasticsearch (`cms-shared-net`).
- При переключении между стеками (Zabbix ↔ ELK) конфиги PostgreSQL (`postgresql.beats.conf` и `zabbix/postgresql.conf`) не конфликтуют, так как находятся в разных директориях монтирования.
- Если Filebeat не читает новые файлы — удалить registry: `docker compose rm -sf filebeat && docker volume rm filebeat_data`.
