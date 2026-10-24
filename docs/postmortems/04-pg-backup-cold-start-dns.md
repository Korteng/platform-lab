# 04. Плановый бэкап Postgres упал на холодном старте кластера

Дата: 2026-10-24.

## Что случилось
После перезагрузки компьютера (отказал кабель монитора) кластер поднялся с нуля. Плановый запуск CronJob `pg-backup` (первое наблюдавшееся срабатывание по расписанию) завершился `Failed 0/1`. Лог пода:

    pg_dump: error: could not translate host name "postgres" to address: Temporary failure in name resolution

Ручной запуск на уже поднявшемся кластере прошёл полностью (`VERIFY OK`, `BACKUP OK`, счётчики `app_user 1, budget 1, category 4, transaction 1`).

## Причина
Имя `postgres` не резолвилось, пока кластер ещё стартовал. Вывод: DNS кластера не успел подняться к моменту запуска Job'а (события CoreDNS не сохранялись и не проверялись, вывод по косвенным признакам). Усугубляли два свойства самого Job'а: `backoffLimit: 0` (ни одной повторной попытки) и отсутствие ожидания готовности БД перед `pg_dump`.

## Как заметил
Только потому, что вручную смотрел `kubectl get pods`. Алерта на упавшие Job'ы нет: kube-state-metrics не установлен (оговорка W5), метрик состояния Job'ов в VictoriaMetrics нет.

## Исправление
`charts/infra/templates/postgres-backup.yaml`:
- `backoffLimit: 3` вместо 0;
- перед `pg_dump` цикл ожидания `pg_isready` (до 24 попыток по 5 секунд, затем явная ошибка `postgres not ready`).

## Проверка
`kubectl scale statefulset postgres --replicas=0`, запуск Job'а из CronJob, возврат `--replicas=1` примерно через 20 секунд после старта. В логе 12 строк `waiting for postgres`, затем `VERIFY OK` и `BACKUP OK`.

## Что не проверено
- Исчерпание 24 попыток (Job упал бы с `postgres not ready`) и срабатывание ретраев `backoffLimit`.
- Алертинг на упавшие бэкапы: по-прежнему нет, нужен kube-state-metrics или метрика свежести последнего бэкапа.
- Причина DNS-сбоя не подтверждена событиями CoreDNS.
