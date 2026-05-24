# OTUS: Logstash и Vector для парсинга логов

Репозиторий подготовлен на основе стенда OTUS с тремя compose-файлами:
- `compose.core.yml` — приложение и генерация логов (`nginx`, `php`, `postgres`)
- `compose.elk.*.yml` — Elasticsearch/Kibana + транспорт парсинга (`logstash` или `vector`)
- `compose.beats.*.yml` — Filebeat/Metricbeat, который можно переключать между прямой отправкой в Elasticsearch и отправкой в Logstash

## Рекомендуемая структура репозитория

```text
.
├── compose.core.yml
├── compose.elk.logstash.yml
├── compose.elk.vector.yml
├── compose.beats.elasticsearch.yml
├── compose.beats.logstash.yml
├── beats/
│   ├── filebeat/
│   │   ├── filebeat.to-elasticsearch.yml
│   │   └── filebeat.to-logstash.yml
│   ├── metricbeat/
│   └── heartbeat/
├── logstash/
│   ├── config/logstash.yml
│   └── pipeline/logstash.conf
├── vector/
│   └── vector.yaml
├── docs/
│   └── ilm-policy.json
├── screenshots/
└── README.md
```

## Зачем так разбивать

Главная идея — **разделять роли по слоям**:
- `core` — всегда один и тот же, это источник логов
- `elk` — поисковый стек и компонент парсинга/доставки
- `beats` — агентский слой

За счёт этого можно быстро переключать варианты без переписывания исходных файлов:
- прямой Filebeat → Elasticsearch
- Filebeat → Logstash → Elasticsearch
- Vector → Elasticsearch

## Быстрое переключение стеков

### 1. Базовое приложение

```bash
docker compose -f compose.core.yml up -d
```

### 2. Вариант A: Filebeat -> Logstash -> Elasticsearch

```bash
docker compose -f compose.elk.logstash.yml up -d
docker compose -f compose.beats.logstash.yml up -d
```

### 3. Вариант B: Filebeat -> Elasticsearch напрямую

```bash
docker compose -f compose.elk.logstash.yml up -d elasticsearch kibana heartbeat
docker compose -f compose.beats.elasticsearch.yml up -d
```

### 4. Вариант C: Vector -> Elasticsearch

В этом варианте Filebeat для логов не нужен, так как Vector читает те же каталоги логов напрямую.

```bash
docker compose -f compose.elk.vector.yml up -d
```

## Как лучше организовать репозиторий для возврата к Beats или смены стека

Лучший практический вариант — не редактировать один и тот же `compose.beats.yml`, а держать **несколько маленьких профильных compose-файлов** и переключаться только комбинацией `-f`.

То есть:
- не менять вручную `output.elasticsearch` на `output.logstash` в одном файле;
- не комментировать сервисы в compose;
- не делать одну огромную `docker-compose.yml` на всё сразу.

Надёжнее держать:
- отдельный compose для `core`;
- отдельный compose для `elk + logstash`;
- отдельный compose для `elk + vector`;
- отдельные конфиги Filebeat под каждый сценарий.

Тогда откат к старому варианту занимает одну команду `down` и одну команду `up`.

## Остановка и переключение

### Остановить Logstash-стек

```bash
docker compose -f compose.beats.logstash.yml down
docker compose -f compose.elk.logstash.yml down
```

### Переключиться на Vector

```bash
docker compose -f compose.elk.vector.yml up -d
```

### Вернуться к прямому Beats

```bash
docker compose -f compose.elk.logstash.yml up -d elasticsearch kibana heartbeat
docker compose -f compose.beats.elasticsearch.yml up -d
```

## ILM для Logstash

Перед запуском Logstash создайте политику ILM в Kibana Dev Tools:

```http
PUT _ilm/policy/logs-app-policy
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "5gb",
            "max_age": "7d"
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

Готовый JSON также лежит в `docs/ilm-policy.json`.

## Что проверять в Kibana

В `Discover` проверьте, что появились поля:
- для nginx: `nginx.remote_addr`, `nginx.method`, `nginx.status`
- для php-fpm: `php_fpm.level`
- для postgresql: `postgresql.pid`, `postgresql.level`

Для Logstash-сценария удобно смотреть alias/индекс `logs-app*`.
Для Vector-сценария — `vector-logs-*`.

## Что приложить к ДЗ

- конфиги Logstash и Vector;
- скриншоты Kibana Discover;
- скриншот ILM policy;
- при наличии звёздочки — подтверждение DLQ (`dead_letter_queue.enable: true` и volume для `logstash_data`).

## Замечания

1. Паттерны `grok` и `parse_regex` могут потребовать подстройки под реальный формат ваших логов.
2. Для учебного задания удобнее маркировать потоки через `fields.log_type` в Filebeat, чем пытаться определять тип только по пути файла.
3. Vector в этом наборе конфигов читает файлы напрямую — это проще и стабильнее для демонстрации VRL.
