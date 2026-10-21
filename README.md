# platform-lab

Инфраструктурный проект: эксплуатация микросервисного приложения [Finance Manager](https://github.com/Korteng/finance-manager) (Java/Spring Boot, Kafka, RabbitMQ, Redis, PostgreSQL, Eureka, Spring Cloud Gateway, Camunda 7) как платформы. Код приложения здесь не дублируется, берётся из соседней папки.

Цель: пройти путь Java-разработчика к Platform/DevOps на реальном стеке: контейнеризация, Kubernetes + Helm, CI/CD (GitHub Actions + GitLab CI), Ansible, observability, эксплуатация БД и брокеров.

## Статус

| Этап | Содержание | Статус |
|---|---|---|
| W1 | Docker: общий Dockerfile, healthcheck, лимиты, compose с профилями | готово |
| W2 | kind + Helm-чарт, HPA, Ingress | план |
| W3 | GitLab CI + GitHub Actions | план |
| W4 | Ansible: подготовка хоста | план |
| W5 | Observability: VictoriaMetrics, Grafana, Loki/Vector, алерты, runbook | план |
| W6 | Postgres backup/restore, Kafka, Redis, Nginx/HAProxy, TLS, postmortem | план |

## Быстрый старт

Нужно: Docker с Compose v2 и BuildKit, GNU Make (в WSL2 Ubuntu есть из коробки), исходники Finance Manager рядом (`../finance-manager`).

```bash
cp .env.example .env     # поменяй пароли и APP_JWT_SECRET
make up                  # ядро: БД, Kafka, RabbitMQ, Redis, Eureka, app, gateway, frontend
make up PROFILES="notifications"            # + notification-service и его БД
make up PROFILES="notifications bpm observability"   # всё
make ps                  # состояние и health
make stats               # память и CPU по контейнерам
make down
```

Фронтенд: http://localhost:3001, API gateway: http://localhost:8090, Eureka: http://localhost:8761.

## Профили (под слабое железо)

| Профиль | Что добавляет | Зачем отдельно |
|---|---|---|
| (по умолчанию) | postgres, redis, rabbitmq, kafka, discovery-server, app, api-gateway, frontend | минимальный рабочий стек |
| `notifications` | notification-service + БД | Kafka consumer, не нужен для всех сценариев |
| `bpm` | camunda-service + БД | тяжёлый (Camunda), включать по необходимости |
| `observability` | python-observer, Prometheus, Grafana | замеры и дашборды |

Лимиты памяти заданы в `compose.yaml` (`mem_limit`), JVM берёт долю от лимита (`-XX:MaxRAMPercentage=75`).

## Что сделано в W1

- Один общий `docker/java-service.Dockerfile` на все Java-сервисы вместо пяти копий: multi-stage, BuildKit-кэш Maven, non-root, `HEALTHCHECK` на actuator, `ExitOnOutOfMemoryError`.
- Фронтенд на `nginx-unprivileged` (не root, порт 8080).
- `docker compose` с профилями, `depends_on: service_healthy`, лимитами памяти.
- `Makefile` с командами для повседневной работы.

## Результаты замеров W1 (десктоп: 3 ядра, 8 ГБ ОЗУ, WSL2, Docker Desktop)

Ядро (8 контейнеров, без профилей):

| Сервис | Память (факт / лимит) |
|---|---|
| fm-app | 392 МиБ / 512 МиБ |
| fm-kafka | 329 МиБ / 768 МиБ |
| fm-gateway | 206 МиБ / 384 МиБ |
| fm-discovery | 202 МиБ / 384 МиБ |
| fm-rabbitmq | 122 МиБ / 384 МиБ |
| fm-postgres | 62 МиБ / 256 МиБ |
| fm-redis | 13 МиБ / 64 МиБ |
| fm-frontend | 7 МиБ / 64 МиБ |
| **Итого** | **~1.3 ГиБ** |

- Размеры образов: app 699 МБ, discovery 538 МБ, gateway 518 МБ, frontend 74 МБ.
- Холодная сборка всех образов: ~445 с (из них ~390 с первая загрузка Maven-зависимостей; повторная сборка использует BuildKit-кэш).
- Старт `fm-app` под нагрузкой одновременного подъёма стека: ~110 с, healthcheck настроен с запасом (`start_period` 120 с).
- RabbitMQ на этой машине стартует ~49 с, Kafka ~40+ с: `start_period` увеличен до 90 с (первая версия с 20 с ложно помечала RabbitMQ как unhealthy).
- Приёмка: `make up` поднимает ядро одной командой, сквозной сценарий (регистрация, транзакция, бюджет через gateway) проверен в браузере.

## Известные ограничения (задел на следующие этапы)

- (закрыто в W2) В `discovery-server` и `api-gateway` добавлен `spring-boot-starter-actuator`, healthcheck теперь штатный `/actuator/health`, включены liveness/readiness-пробы.
- Образы тяжёлые (500-700 МБ на Java-сервис): кандидаты на оптимизацию, слоёный jar (`layertools`), JRE alpine/jlink. Исходные образы до рефакторинга не замерялись, сравнения «до/после» нет.
- `fm-app` использует 76% лимита 512 МиБ: при росте нагрузки лимит поднять.
- Секреты в `.env`, в K8s будут через Secret (W2).
