# Профили: notifications, bpm, observability. Пример: make up PROFILES="notifications observability"
PROFILES ?=
COMPOSE = docker compose $(foreach p,$(PROFILES),--profile $(p))

.PHONY: help env up down build ps logs stats sizes clean

help:        ## список команд
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/ :/'

env:         ## создать .env из .env.example (если нет)
	@test -f .env || (cp .env.example .env && echo ".env создан, поменяй пароли и APP_JWT_SECRET")

up: env      ## поднять стек
	DOCKER_BUILDKIT=1 $(COMPOSE) up -d --build

down:        ## остановить (тома сохраняются)
	$(COMPOSE) down

build:       ## только сборка образов
	DOCKER_BUILDKIT=1 $(COMPOSE) build

ps:          ## состояние и health
	$(COMPOSE) ps

logs:        ## логи, make logs S=app
	$(COMPOSE) logs -f --tail=100 $(S)

stats:       ## потребление памяти и CPU
	docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}"

sizes:       ## размеры образов проекта
	docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep platform-lab

clean:       ## остановить и удалить тома (данные пропадут)
	$(COMPOSE) down -v
