# Data Prepper

Data Prepper развёрнут на VM2 как отдельный ingestion-сервис для OpenSearch. Он работает параллельно основной цепочке `Graylog Sidecar → Graylog → OpenSearch` и демонстрирует "родной" для OpenSearch способ приёма и обработки событий через настраиваемые пайплайны.

## Архитектура Data Prepper

В этой схеме Data Prepper используется как отдельный ingestion-сервис для OpenSearch.

Поток данных:

1. HTTP-клиент (`curl`, Fluent Bit или приложение) отправляет JSON-события на `http://<VM2_IP>:2021/logs`.
2. Data Prepper принимает события через `source: http`.
3. Затем Data Prepper обрабатывает их в pipeline:
   - `parse_json` — разбирает JSON,
   - `date` — добавляет `@timestamp`,
   - `delete_entries` — удаляет лишние технические поля.
4. После обработки Data Prepper записывает документы в OpenSearch.
5. Документы сохраняются в индекс `dataprepper-demo-YYYY.MM.dd`.

## Отправка тестового события

Data Prepper HTTP source ожидает **массив JSON-объектов** `[...]`:

```bash
curl -X POST "http://localhost:2021/logs"   -H "Content-Type: application/json"   -d '[
    {
      "service": "demo-app",
      "level": "INFO",
      "message": "dataprepper single test message",
      "source_type": "manual-test"
    }
  ]'
```

Можно отправить несколько событий за один запрос:

```bash
curl -X POST "http://localhost:2021/logs"   -H "Content-Type: application/json"   -d '[
    {
      "service": "demo-app",
      "level": "INFO",
      "message": "first test message",
      "source_type": "manual-test"
    },
    {
      "service": "demo-app",
      "level": "ERROR",
      "message": "second test message",
      "source_type": "manual-test"
    }
  ]'
```

## Проверка индексов в OpenSearch

Список всех индексов:

```bash
curl "http://localhost:9200/_cat/indices?v"
```

Полученный результат — наличие индекса вида `dataprepper-demo-YYYY.MM.dd`:

```txt
yellow open   dataprepper-demo-2026.06.15 cVSx_nziSEifWDb9DeqKZg   1   1          3            0       12kb           12kb
```

## Поиск по индексу

```bash
curl -X GET "http://localhost:9200/dataprepper-demo-*/_search?pretty" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "match_all": {}
    }
  }'
```

Поиск по конкретному полю:

```bash
curl -X GET "http://localhost:9200/dataprepper-demo-*/_search?pretty" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "match": {
        "source_type": "manual-test"
      }
    }
  }'
```

Пример ответа OpenSearch:

```json
{
  "took" : 7,
  "timed_out" : false,
  "_shards" : {
    "total" : 2,
    "successful" : 2,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : {
      "value" : 3,
      "relation" : "eq"
    },
    "max_score" : 0.26706278,
    "hits" : [
      {
        "_index" : "dataprepper-demo-2026.06.15",
        "_id" : "J0vQyp4B4M-D5XPQtrpT",
        "_score" : 0.26706278,
        "_source" : {
          "service" : "demo-app",
          "level" : "INFO",
          "message" : "dataprepper single test message",
          "source_type" : "manual-test"
        }
      },
      {
        "_index" : "dataprepper-demo-2026.06.15",
        "_id" : "KEvRyp4B4M-D5XPQobq9",
        "_score" : 0.26706278,
        "_source" : {
          "service" : "demo-app",
          "level" : "INFO",
          "message" : "first test message",
          "source_type" : "manual-test"
        }
      },
      {
        "_index" : "dataprepper-demo-2026.06.15",
        "_id" : "KUvRyp4B4M-D5XPQobq9",
        "_score" : 0.26706278,
        "_source" : {
          "service" : "demo-app",
          "level" : "ERROR",
          "message" : "second test message",
          "source_type" : "manual-test"
        }
      }
    ]
  }
}
```

## Описание компонентов

| Компонент | Роль |
| :-- | :-- |
| HTTP source | Приём JSON-массивов событий на порту `2021` |
| `parse_json` | Разбор JSON-содержимого каждого события |
| `date` | Нормализация `@timestamp` по времени получения события |
| `delete_entries` | Удаление технических полей перед записью в индекс |
| OpenSearch sink | Запись обработанных документов в `dataprepper-demo-*` |

## Сравнение двух путей доставки логов

|  | Graylog Sidecar → Graylog | Data Prepper → OpenSearch |
| :-- | :-- | :-- |
| Агент | Filebeat (управляется Sidecar) | Fluent Bit / curl / приложение |
| Управление конфигами | Через Graylog UI (теги, Sidecar) | Через `pipelines.yaml` |
| UI для просмотра | Graylog (streams, search, alerts) | OpenSearch Dashboards |
| Применение | Централизованный сбор логов CMS | Nативный ingestion-пайплайн OpenSearch |
| Индексы | `graylog_0` | `dataprepper-demo-*` |

В данной работе основной путь логов CMS идёт через `Graylog Sidecar → Graylog → OpenSearch`, а Data Prepper развёрнут как дополнительный ingestion-сервис, демонстрирующий альтернативный путь доставки событий напрямую в OpenSearch.
