#!/usr/bin/env bash
# Kafka basics: партиции/ключи и retention на тестовом топике partition-lab.
# Использование: scripts/kafka-lab.sh partitions | retention | cleanup
set -euo pipefail

NS=finance-manager
POD=kafka-0
BS=localhost:9092
TOPIC=partition-lab
K() { kubectl -n "$NS" exec "$POD" -- "$@"; }
KI() { kubectl -n "$NS" exec -i "$POD" -- "$@"; }

case "${1:-}" in
  partitions)
    K kafka-topics --bootstrap-server "$BS" --create --topic "$TOPIC" --partitions 3 --replication-factor 1
    printf 'userA:1\nuserB:1\nuserC:1\nuserA:2\nuserB:2\nuserC:2\nuserA:3\nuserB:3\nuserC:3\n' \
      | KI kafka-console-producer --bootstrap-server "$BS" --topic "$TOPIC" --property parse.key=true --property key.separator=:
    echo "--- сообщения по партициям (TimeoutException в конце ожидаем: выход по --timeout-ms)"
    K kafka-console-consumer --bootstrap-server "$BS" --topic "$TOPIC" --from-beginning --timeout-ms 5000 \
      --property print.key=true --property print.partition=true || true
    echo "--- end offsets"
    K kafka-get-offsets --bootstrap-server "$BS" --topic "$TOPIC"
    ;;
  retention)
    K kafka-configs --bootstrap-server "$BS" --alter --entity-type topics --entity-name "$TOPIC" \
      --add-config retention.ms=60000,segment.ms=60000
    echo "--- earliest (до)"
    K kafka-get-offsets --bootstrap-server "$BS" --topic "$TOPIC" --time -2
    echo "ждём 7 минут (проверка удаления идёт раз в 5 минут)"
    sleep 420
    echo "--- earliest (после)"
    K kafka-get-offsets --bootstrap-server "$BS" --topic "$TOPIC" --time -2
    echo "--- latest"
    K kafka-get-offsets --bootstrap-server "$BS" --topic "$TOPIC" --time -1
    ;;
  cleanup)
    K kafka-topics --bootstrap-server "$BS" --delete --topic "$TOPIC" || true
    K kafka-consumer-groups --bootstrap-server "$BS" --delete --group lab-group >/dev/null 2>&1 || true
    ;;
  *)
    echo "usage: $0 partitions|retention|cleanup" >&2; exit 1 ;;
esac
