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

# ---------- Kubernetes (kind) ----------
NS ?= finance-manager
IMAGES = discovery-server finance-manager-app api-gateway frontend

.PHONY: k-up k-load k-secrets k-infra k-deploy k-status k-down

k-up:        ## создать kind-кластер (один нод)
	kind create cluster --config k8s/kind-config.yaml

k-load:      ## загрузить образы из Docker в kind (сначала make build)
	for i in $(IMAGES); do kind load docker-image platform-lab/$$i:dev --name platform-lab || exit 1; done

k-secrets: env  ## namespace и Secret fm-secrets из .env
	kubectl create namespace $(NS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n $(NS) create secret generic fm-secrets --from-env-file=.env --dry-run=client -o yaml | kubectl apply -f -

k-infra: k-secrets  ## PostgreSQL, Redis, RabbitMQ, Kafka
	helm upgrade --install infra charts/infra -n $(NS)

k-deploy:    ## сервисы Finance Manager
	helm upgrade --install fm charts/finance-manager -n $(NS) --atomic --timeout 10m

k-status:    ## поды, сервисы, тома
	kubectl -n $(NS) get pods,svc,pvc

k-down:      ## удалить кластер целиком
	kind delete cluster --name platform-lab

k-metrics: ## metrics-server для kind
	helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
	helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system --set "args={--kubelet-insecure-tls}"

# W4 Ansible
ANSIBLE_CONFIG := $(CURDIR)/ansible/ansible.cfg
export ANSIBLE_CONFIG

.PHONY: a-build a-target a-ping a-run a-check

a-build:
	docker build -f docker/ansible-target.Dockerfile -t platform-lab/ansible-target:dev docker/

a-target:
	docker start ansible-target || docker run -d --name ansible-target --memory 256m -p 2222:22 -e PUBKEY="$$(cat ~/.ssh/platform_lab_ansible.pub)" platform-lab/ansible-target:dev

a-ping:
	ansible lab -m ping

a-run:
	ansible-playbook ansible/site.yml

a-check:
	ansible-playbook ansible/site.yml --check --diff
