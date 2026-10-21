# syntax=docker/dockerfile:1.7
# Общий Dockerfile для всех Java-сервисов Finance Manager.
# Контекст сборки: корень finance-manager, модуль задаётся через --build-arg MODULE=<dir>.

FROM maven:3.9-eclipse-temurin-17 AS build
ARG MODULE
WORKDIR /app
COPY ${MODULE}/pom.xml .
# BuildKit-кэш ~/.m2: зависимости не качаются заново при каждой сборке
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline
COPY ${MODULE}/src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -q package -DskipTests

FROM eclipse-temurin:17-jre
ARG PORT=8080
WORKDIR /app
RUN useradd -r -u 1001 appuser
USER appuser
COPY --from=build --chown=appuser /app/target/*.jar app.jar
EXPOSE ${PORT}
ENV PORT=${PORT}
# Лимиты контейнера задаёт compose/k8s, JVM берёт долю от cgroup, а не от памяти хоста
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"
HEALTHCHECK --interval=15s --timeout=5s --start-period=120s --retries=8 \
  CMD curl -fsS "http://localhost:${PORT}/actuator/health" || exit 1
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
