# Postmortems

Разборы реальных сбоев в платформе. Формат: кратко, влияние, как обнаружили, причина, что сделали, что не сделано. Цифры только те, что были измерены, остальное помечено как не записанное.

| # | Сбой | Этап | Файл |
|---|---|---|---|
| 1 | Шторм рестартов подов на слабой машине из-за дефолтных проб | W2 | [01-probe-restart-storm.md](01-probe-restart-storm.md) |
| 2 | Деплой падает по `context deadline exceeded` из-за surge при rolling update | W3 | [02-deploy-surge-timeout.md](02-deploy-surge-timeout.md) |
| 3 | Scrape экспортёра Kafka падает: брокер объявляет имя, которое не резолвится из другого namespace | W5 | [03-kafka-exporter-dns.md](03-kafka-exporter-dns.md) |
| 4 | Плановый бэкап Postgres упал на холодном старте: имя postgres не резолвилось, Job без ретраев | W6 | [04-pg-backup-cold-start-dns.md](04-pg-backup-cold-start-dns.md) |

## Мелкие инциденты без отдельного разбора

- `helm upgrade --atomic` зависал на PVC в `Pending`: StorageClass `standard` в kind использует `WaitForFirstConsumer`, а pod у CronJob появляется только по расписанию. Решение: ставить чарт без `--wait`.
- Loki падал с `mkdir /var/loki: read-only file system`: без PV чарт не монтирует каталог данных. Решение: PV 2Gi, sidecar правил выключен.
- Vector: Service без портов отвергался API, `{{ }}` в labels воспринимались как шаблон Helm. Решение: `service.enabled: false` и экранирование.
- cAdvisor отвечал 403: у ServiceAccount VictoriaMetrics не было прав на `nodes/proxy`. Решение: ClusterRole и ClusterRoleBinding.
- Helm для Traefik падал из-за Service типа LoadBalancer: в этой версии чарта ключ `service.spec.type`, а не `service.type`.
- Ansible игнорировал `ansible.cfg` в `/mnt/c` (каталог доступен на запись всем). Решение: `ANSIBLE_CONFIG` в Makefile.

## Находка без исправления

Readiness probe приложения не включает БД: при остановленном Postgres под остаётся `Ready`, `/actuator/health` отдаёт 503, трафик продолжает идти на неработающий под. Сработал алерт `High5xxRate`, но маршрутизация не отреагировала.
