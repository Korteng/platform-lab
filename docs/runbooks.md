# Runbooks

Алерты описаны в `monitoring/vmalert-values.yaml`. Namespace приложения: `finance-manager`.

## AppDown

Метрики приложения не скрейпятся (`up == 0`).

Проверить:

    kubectl -n finance-manager get pods
    kubectl -n finance-manager describe pod -l app=finance-manager-app
    kubectl -n finance-manager logs deploy/finance-manager-app --tail=100

Частые причины:
- под в CrashLoopBackOff или OOMKilled
- упал postgres или kafka, приложение не стартует
- сломан путь `/actuator/prometheus` или изменилась метка пода `app`
- WSL или нода kind остановлены (`docker ps`)

Действия: починить причину, при необходимости `kubectl -n finance-manager rollout restart deploy finance-manager-app`.

## PodRestarted

Контейнер перезапускался (`changes(container_start_time_seconds)` за 10m). kube-state-metrics не установлен, поэтому это приближение. Срабатывает и на плановый рестарт StatefulSet.

Проверить:

    kubectl -n finance-manager get pods
    kubectl -n finance-manager describe pod <pod> | grep -A5 "Last State"
    kubectl -n finance-manager logs <pod> --previous --tail=100

Частые причины:
- OOMKilled (Last State: Terminated, Reason: OOMKilled), см. HighMemory
- провал liveness probe (timeoutSeconds слишком мал под нагрузкой)
- ошибка при старте приложения
- плановый рестарт или scale зависимости

Действия: поднять limits или исправить пробы, перекатить деплой.

## High5xxRate

Доля ответов 5xx выше 5% за окно 2m.

Проверить:

    kubectl -n finance-manager logs deploy/finance-manager-app --tail=200
    kubectl -n finance-manager get pods
    kubectl -n finance-manager port-forward deploy/finance-manager-app 8080:8080
    curl -s localhost:8080/actuator/health

Частые причины:
- недоступна БД: `/actuator/health` отдаёт 503. Readiness probe БД не проверяет, поэтому под остаётся Ready и трафик на него идёт
- недоступен kafka или redis
- ошибка после свежего релиза: сравнить с последним деплоем (`helm history`)

Действия: восстановить зависимость (`kubectl -n finance-manager get statefulset`), при необходимости откатить релиз `helm rollback`.

## HighMemory

Память контейнера близка к limit.

Проверить:

    kubectl -n finance-manager top pod
    kubectl -n finance-manager describe pod <pod> | grep -A3 Limits

Частые причины:
- утечка или рост кеша
- heap JVM не согласован с limit контейнера
- всплеск нагрузки, HPA ещё не добавил реплику

Действия: временно поднять limits в values чарта, смотреть тренд на дашборде, при утечке снять heap dump.
