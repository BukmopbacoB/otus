# План миграции на multi-stack без потери данных

Ниже безопасная последовательность перехода от одного большого `docker-compose.yml` к схеме:

- `compose.core.yml`
- `compose.gap.yml`
- `compose.zabbix.yml`
- `compose.tick.yml`

Цель: сохранить CMS, конфиги, данные PostgreSQL и при этом начать запускать GAP / Zabbix / TICK независимо.

---

## Что именно сохраняется

### Сохранится автоматически

Если вы **не используете** `docker compose down -v`, то сохранятся:

- данные PostgreSQL в named volume `pgdata`;
- данные Grafana в `grafana_data`;
- данные VictoriaMetrics в `vmdata`;
- данные Prometheus в `prometheus_data`;
- данные Zabbix в `zbx_pgdata`;
- все bind mounts, потому что это обычные файлы на хосте: `./src`, `./nginx/conf.d`, `./postgres`, `./prometheus`, `./alertmanager`, `./zabbix`, `./tick-1`.

### Что можно потерять

Вы потеряете данные только если:

- выполните `docker compose down -v`;
- выполните `docker volume rm ...`;
- удалите каталоги проекта на хосте;
- переименуете volume и потом создадите новый пустой volume с другим именем.

---

## Безопасная стратегия

### Этап 0. Сделать резервную копию перед миграцией

Минимум, что стоит сохранить:

```bash
cp -r src src.bak
cp -r nginx nginx.bak
cp -r postgres postgres.bak
cp -r prometheus prometheus.bak
cp -r alertmanager alertmanager.bak
cp -r zabbix zabbix.bak
cp -r tick-1 tick-1.bak
cp .env .env.bak
```

Посмотреть текущие volume:

```bash
docker volume ls
```

Если хочется совсем надежно, можно отдельно сделать дамп PostgreSQL CMS:

```bash
docker exec -t cms-postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > cms.sql
```

И при наличии Zabbix — дамп его БД:

```bash
docker exec -t zabbix-postgres pg_dump -U zabbix zabbix > zabbix.sql
```

---

## Этап 1. Зафиксировать текущее состояние

Посмотреть, что сейчас реально запущено:

```bash
docker ps -a
```

Посмотреть сети:

```bash
docker network ls
```

Посмотреть volumes:

```bash
docker volume ls
```

Это нужно, чтобы потом понимать, какие контейнеры и volumes были до миграции.

---

## Этап 2. Аккуратно остановить старый монолитный compose

Из каталога, где лежал старый единый `docker-compose.yml`, выполните:

```bash
docker compose down --remove-orphans
```

Важно:

- **не добавляйте `-v`**;
- `--remove-orphans` полезен, если compose-файл уже менялся, и могли остаться старые контейнеры.

После этого контейнеры остановятся и удалятся, но named volumes сохранятся.

---

## Этап 3. Разложить новые compose-файлы

Положите в корень проекта:

- `compose.core.yml`
- `compose.gap.yml`
- `compose.zabbix.yml`
- `compose.tick.yml`

Не переносите сами каталоги конфигов, если они уже лежат на своих местах:

- `./src`
- `./nginx/conf.d`
- `./postgres`
- `./prometheus`
- `./alertmanager`
- `./zabbix`
- `./tick-1`

То есть миграция касается в основном **способа запуска**, а не структуры данных.

---

## Этап 4. Поднять сначала только core

Запустите только CMS:

```bash
docker compose -f compose.core.yml up -d
```

Проверьте:

```bash
docker ps
```

Должны подняться:

- `cms-nginx`
- `cms-php`
- `cms-postgres`

Проверьте CMS в браузере:

- `http://localhost:8080`

И проверьте, что данные базы на месте.

Если CMS стартовала и контент на месте — значит `pgdata` успешно подцепился к новому compose.

---

## Этап 5. Проверить общую сеть

После старта core должна появиться сеть `cms-shared-net`.

Проверка:

```bash
docker network ls | grep cms-shared-net
```

При необходимости можно посмотреть подключенные контейнеры:

```bash
docker network inspect cms-shared-net
```

---

## Этап 6. Поднимать monitoring-стеки по одному

Сначала GAP:

```bash
docker compose -f compose.gap.yml up -d
```

Проверить:

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

Потом Zabbix:

```bash
docker compose -f compose.zabbix.yml up -d
```

Проверить:

- Zabbix UI: `http://localhost:8082`

Потом TICK:

```bash
docker compose -f compose.tick.yml up -d
```

Проверить:

- Chronograf: `http://localhost:8888`
- InfluxDB: `http://localhost:8086`
- Kapacitor: `http://localhost:9092`

Если хотите минимизировать риски, поднимайте сначала только один monitoring-стек, убеждайтесь, что он видит `nginx` и `db`, и только потом добавляйте следующий.

---

## Этап 7. Проверить связность между проектами

Проверки по смыслу:

### GAP

- `nginx-exporter` должен видеть `http://nginx/nginx_status`;
- `postgres-exporter` должен подключаться к `db:5432`.

### TICK

- `telegraf` должен ходить на `http://nginx/nginx_status`;
- `telegraf` должен ходить к `db:5432`;
- `chronograf` должен видеть `influxdb` и `kapacitor`.

### Zabbix

- `zabbix-agent` и `zabbix-server` должны работать внутри общей сети;
- при необходимости агент можно донастроить для опроса CMS и PostgreSQL.

Если что-то не резолвится по имени, первым делом проверьте, что контейнеры действительно в сети `cms-shared-net`.

---

## Этап 8. Что делать, если volume не подцепился

Если после запуска `compose.core.yml` CMS пустая или БД как будто новая:

1. Посмотрите, какой volume подключён:

```bash
docker inspect cms-postgres | grep -A 20 Mounts
```

2. Посмотрите список volume:

```bash
docker volume ls
```

3. Возможно, раньше compose создал volume с project-prefix, например:

- `otus_pgdata`
- `myproject_pgdata`

А в новом compose создался просто другой volume.

В таком случае есть два пути:

### Вариант A. Явно использовать старый volume как external

Например, если старый volume называется `otus_pgdata`, в `compose.core.yml` можно временно прописать:

```yaml
volumes:
  pgdata:
    external: true
    name: otus_pgdata
```
```

Тогда новый compose будет использовать существующий старый volume.

### Вариант B. Разово перенести данные вручную

Это нужно только если структура volume уже сильно поменялась. Обычно до этого не доходит.

---

## Этап 9. Как безопасно останавливать дальше

Теперь используйте такую модель:

Остановить только GAP:

```bash
docker compose -f compose.gap.yml down
```

Остановить только Zabbix:

```bash
docker compose -f compose.zabbix.yml down
```

Остановить только TICK:

```bash
docker compose -f compose.tick.yml down
```

Остановить CMS:

```bash
docker compose -f compose.core.yml down
```

Ни в одном из этих случаев не используйте `-v`, если не хотите потерять данные.

---

## Этап 10. Рекомендуемая практика на будущее

- Для обычной работы: `docker compose ... up -d` и `docker compose ... down`.
- Для очистки старых контейнеров после рефакторинга: добавлять `--remove-orphans`.
- Не использовать `down -v`, если это не осознанный полный сброс.
- Перед крупным рефакторингом compose — делать дамп БД и копию каталога проекта.
- Если named volume уже существует со старым именем, лучше подключить его как `external`, чем создавать новый пустой.

---

## Короткий безопасный сценарий

```bash
# 0. backup
cp .env .env.bak
cp -r src src.bak
cp -r nginx nginx.bak
cp -r postgres postgres.bak

# 1. stop old stack without deleting volumes
docker compose down --remove-orphans

# 2. start core
docker compose -f compose.core.yml up -d

# 3. check CMS
# http://localhost:8080

# 4. start monitoring stacks one by one
docker compose -f compose.gap.yml up -d
docker compose -f compose.zabbix.yml up -d
docker compose -f compose.tick.yml up -d
```

---

## Если хотите совсем без риска

Самый осторожный путь:

1. Сделать backup файлов.
2. Сделать `pg_dump` CMS.
3. Сделать `docker compose down --remove-orphans`.
4. Поднять только `compose.core.yml`.
5. Убедиться, что CMS и БД на месте.
6. Только после этого поднимать GAP/Zabbix/TICK.

Именно так шанс что-то потерять минимален.
