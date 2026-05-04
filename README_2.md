# Multi-stack layout

## Состав

- `compose.core.yml` — одна общая CMS: nginx + php + postgres.
- `compose.gap.yml` — стек GAP/Prometheus.
- `compose.zabbix.yml` — стек Zabbix.
- `compose.tick.yml` — стек TICK.

## Порядок запуска

Сначала поднимается общая CMS:

```bash
docker compose -f compose.core.yml up -d
```

Потом можно запускать любой мониторинг или сразу несколько:

```bash
docker compose -f compose.gap.yml up -d
docker compose -f compose.zabbix.yml up -d
docker compose -f compose.tick.yml up -d
```

## Остановка

```bash
docker compose -f compose.gap.yml down
docker compose -f compose.zabbix.yml down
docker compose -f compose.tick.yml down
```

CMS при этом продолжит работать, если не делать:

```bash
docker compose -f compose.core.yml down
```

## Важно

- сеть `cms-shared-net` создаёт `compose.core.yml`;
- остальные compose-файлы используют её как `external: true`;
- имена `nginx`, `php`, `db`, `postgres` доступны monitoring-стекам через network aliases;
- bind mounts (`./src`, `./nginx/conf.d`, `./postgres/...`) сохраняют настройки на хосте;
- named volume `pgdata` сохраняет данные PostgreSQL, пока вы не удалите его явно через `docker volume rm` или `docker compose down -v`.
