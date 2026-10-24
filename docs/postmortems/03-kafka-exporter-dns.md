# Postmortem 3: экспортёр Kafka не может собрать метрики

Этап: W5 (Observability), 2026-10-23.

## Кратко

Экспортёр метрик Kafka, установленный в namespace `monitoring`, не отдавал метрики: target в VictoriaMetrics был `down` с ошибкой `Client.Timeout exceeded while awaiting headers`, метрика `kafka_brokers` была пустой. Причина: брокер в метаданных объявляет себя коротким именем `kafka`, а из другого namespace оно не резолвится. После переноса экспортёра в namespace `finance-manager` метрика `kafka_brokers` стала равна 1, алерт `KafkaConsumerLag` отработал.

## Влияние

Мониторинг lag Kafka не работал, алерт нельзя было проверить. Приложение не пострадало.

## Как обнаружили

1. `kubectl port-forward` на VictoriaMetrics, `curl localhost:8428/targets`: `job=kafka-exporter (0/1 up)`, `state=down`, timeout 10001ms.
2. Логи экспортёра: `Cannot get current offset of topic ... lookup kafka on 10.96.0.10:53: server misbehaving`.
3. Вывод: адрес bootstrap в конфиге был полным (`kafka.finance-manager.svc.cluster.local:9092`), но брокер в ответе на metadata request возвращал адрес `kafka`, и клиент подключался уже к нему.

## Причина

`KAFKA_ADVERTISED_LISTENERS` равен `PLAINTEXT://kafka:9092` (проверено в StatefulSet), то есть брокер объявляет короткое имя `kafka`. Клиент в том же namespace резолвит его, клиент в другом нет. Bootstrap по FQDN этого не исправляет: имя из метаданных подменяет исходное.

## Что сделали

- Перенесли экспортёр в namespace `finance-manager` (`helm upgrade --install kafka-exporter ... -n finance-manager`).
- Обновили адрес в scrape-конфиге VictoriaMetrics на `kafka-exporter-prometheus-kafka-exporter.finance-manager.svc:9308`.
- Проверили: `kafka_brokers = 1`, `kafka_consumergroup_lag` для тестовой группы видна, алерт срабатывает и гаснет.

## Что не сделано

- Не меняли `KAFKA_ADVERTISED_LISTENERS` на FQDN: тогда экспортёр и другие клиенты смогли бы жить в любом namespace. Это правильное исправление, перенос в тот же namespace его обходит.
- Алерт на lag проверен только синтетической группой `lag-test-group`: живого консюмера в деплое нет.

## Выводы

- Для проверок вида «target down» сначала смотреть логи самого экспортёра, а не только статус в Prometheus.
- Адреса брокеров в Kafka надо задавать так, чтобы они были достижимы из всех мест, где живут клиенты.
