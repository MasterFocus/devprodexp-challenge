PREFIX ?= localdev
HTMLCOV_DIR ?= htmlcov
TAG ?= dev
IMAGES := orders products gateway

CF_ORG ?= good
CF_SPACE ?= morning
CF_APP ?= nameko-devex

install-dependencies:
	pip install -U -e "orders/.[dev]"
	pip install -U -e "products/.[dev]"
	pip install -U -e "gateway/.[dev]"

# test

coverage-html:
	coverage html -d $(HTMLCOV_DIR) --fail-under 100

coverage-report:
	coverage report -m

test:
	flake8 orders products gateway
	coverage run -m pytest gateway/test $(ARGS)
	coverage run --append -m pytest orders/test $(ARGS)
	coverage run --append -m pytest products/test $(ARGS)

coverage: test coverage-report coverage-html

# test
smoke-test:
	./test/nex-smoketest.sh http://localhost:8000

perf-test:
	./test/nex-bzt.sh http://localhost:8000

# docker

build-base:
	docker build --target base -t nameko-example-base .;
	docker build --target builder -t nameko-example-builder .;

build: build-base
	for image in $(IMAGES) ; do TAG=$(TAG) make -C $$image build-image; done

deploy-docker: build
	bash -c "trap 'make undeploy-docker' EXIT; PREFIX=${PREFIX} TAG=$(TAG) docker-compose up"

undeploy-docker:
	PREFIX=$(PREFIX) docker-compose down
	
docker-save:
	mkdir -p docker-images
	docker save -o docker-images/examples.tar $(foreach image,$(IMAGES),nameko/nameko-example-$(image):$(TAG))

docker-load:
	docker load -i docker-images/examples.tar

docker-tag:
	for image in $(IMAGES) ; do make -C $$image docker-tag; done

docker-login:
	docker login --password=$(DOCKER_PASSWORD) --username=$(DOCKER_USERNAME)

push-images:
	for image in $(IMAGES) ; do make -C $$image push-image; done

# cf
cf_target:
	cf target -o $(CF_ORG) -s $(CF_SPACE)

cf_cs_postgres:
	cf cs postgresql 11-7-0 $(CF_APP)_postgres
	echo "Waiting for service to be created"
	for i in $$(seq 1 90); do \
		cf service $(CF_APP)_postgres | grep  "create succeeded" 2> /dev/null && break; \
			sleep 1; \
	done 

cf_ds_postgres:
	cf ds $(CF_APP)_postgres -f
	echo "Waiting for service to be deleted"
	for i in $$(seq 1 90); do \
		cf service $(CF_APP)_postgres | grep  "delete in progress" 2> /dev/null || break; \
			sleep 1; \
	done 

cf_cs_rabbitmq:
	cf cs rabbitmq 3-8-1 $(CF_APP)_rabbitmq
	echo "Waiting for service to be created"
	for i in $$(seq 1 90); do \
		cf service $(CF_APP)_rabbitmq | grep  "create succeeded" 2> /dev/null && break; \
			sleep 1; \
	done 

cf_ds_rabbitmq:
	cf ds $(CF_APP)_rabbitmq -f
	echo "Waiting for service to be deleted"
	for i in $$(seq 1 90); do \
		cf service $(CF_APP)_rabbitmq | grep  "delete in progress" 2> /dev/null || break; \
			sleep 1; \
	done 

cf_cs_redis:
	cf cs redis 5-0-7 $(CF_APP)_redis
	echo "Waiting for service to be created"
	for i in $$(seq 1 90); do \
		cf service $(CF_APP)_redis | grep  "create succeeded" 2> /dev/null && break; \
			sleep 1; \
	done 

cf_ds_redis:
	cf ds $(CF_APP)_redis -f
	echo "Waiting for service to be deleted"
	for i in $$(seq 1 90); do \
		cf service $(CF_APP)_redis | grep  "delete in progress" 2> /dev/null || break; \
			sleep 1; \
	done 

deployCF: cf_target cf_cs_postgres cf_cs_rabbitmq cf_cs_redis
	cf delete $(CF_APP) -f
	# create environment.yml file from environment_dev.yml file
	cat environment_dev.yml | grep -v '#dev' > environment.yml
	cf push $(CF_APP) --no-start
	rm -f environment.yml

	cf bind-service $(CF_APP) $(CF_APP)_postgres
	cf bind-service $(CF_APP) $(CF_APP)_rabbitmq
	cf bind-service $(CF_APP) $(CF_APP)_redis
	cf start $(CF_APP)

undeployCF: cf_target 
	cf delete $(CF_APP) -f -r
	$(MAKE) cf_ds_postgres
	$(MAKE) cf_ds_rabbitmq
	$(MAKE) cf_ds_redis

# ================================================
# Targets related to Epinio
# ================================================

# ------------------------------------------------
# Select a namespace to work with
# ------------------------------------------------
epinio_target:
ifndef EPINIO_NS
	$(error EPINIO_NS is undefined)
endif
	epinio namespace show $(EPINIO_NS) || epinio namespace create $(EPINIO_NS)
	epinio target $(EPINIO_NS)

# ------------------------------------------------
# Create the Service - POSTGRESQL
# ------------------------------------------------
epinio_cs_postgres:
ifndef EPINIO_APP
	$(error EPINIO_APP is undefined)
endif
	epinio service create postgresql-dev $(EPINIO_APP)_postgresql

# ------------------------------------------------
# Destroy the Service - POSTGRESQL
# ------------------------------------------------
epinio_ds_postgres:
ifndef EPINIO_APP
	$(error EPINIO_APP is undefined)
endif
	epinio service delete $(EPINIO_APP)_postgresql --unbind

# ------------------------------------------------
# Create the Service - RABBITMQ
# ------------------------------------------------
epinio_cs_rabbitmq:
ifndef EPINIO_APP
	$(error EPINIO_APP is undefined)
endif
	epinio service create rabbitmq-dev $(EPINIO_APP)_rabbitmq

# ------------------------------------------------
# Destroy the Service - RABBITMQ
# ------------------------------------------------
epinio_ds_rabbitmq:
ifndef EPINIO_APP
	$(error EPINIO_APP is undefined)
endif
	epinio service delete $(EPINIO_APP)_rabbitmq --unbind

# ------------------------------------------------
# Create the Service - REDIS
# ------------------------------------------------
epinio_cs_redis:
ifndef EPINIO_APP
	$(error EPINIO_APP is undefined)
endif
	epinio service create redis-dev $(EPINIO_APP)_redis

# ------------------------------------------------
# Destroy the Service - REDIS
# ------------------------------------------------
epinio_ds_redis:
ifndef EPINIO_APP
	$(error EPINIO_APP is undefined)
endif
	epinio service delete $(EPINIO_APP)_redis --unbind

# ------------------------------------------------
# Create all Services at once - POSTGRESQL RABBITMQ REDIS
# ------------------------------------------------
epinio_cs_all: epinio_cs_postgres epinio_cs_rabbitmq epinio_cs_redis

# ------------------------------------------------
# Destroy all Services at once - POSTGRESQL RABBITMQ REDIS
# ------------------------------------------------
epinio_ds_all: epinio_ds_postgres epinio_ds_rabbitmq epinio_ds_redis

# ------------------------------------------------
# Select the namespace, create all Services and deploy the App
# ------------------------------------------------
epinio_deploy: epinio_target epinio_cs_all
#	Create the "empty" App
	epinio app delete $(EPINIO_APP) || echo "App didn't exist - nothing to delete. Proceeding..."
	epinio app create $(EPINIO_APP)
#	Bind Service and then bind our custom Configuration - POSTGRESQL
	epinio service bind $(EPINIO_APP)_postgresql $(EPINIO_APP)
	./formURI.sh $(EPINIO_APP)_postgresql 'postgresql.$(EPINIO_NS).svc.cluster.local:5432' 'postgresql://postgres:%PASS%@%HOST%/devex' > .tmp-uri
	echo -n "epinio configuration create $(EPINIO_APP)-postgresql-cfg POSTGRES_URI " > .tmp-script
	cat .tmp-uri >> .tmp-script
	bash .tmp-script
	epinio configuration bind $(EPINIO_APP)-postgresql-cfg $(EPINIO_APP)
#	Bind Service and then bind our custom Configuration - RABBITMQ
	epinio service bind $(EPINIO_APP)_rabbitmq $(EPINIO_APP)
	./formURI.sh $(EPINIO_APP)_rabbitmq 'rabbitmq.$(EPINIO_NS).svc.cluster.local:5672' 'amqp://user:%PASS%@%HOST%' > .tmp-uri
	echo -n "epinio configuration create $(EPINIO_APP)-rabbitmq-cfg AMQP_URI " > .tmp-script
	cat .tmp-uri >> .tmp-script
	bash .tmp-script
	epinio configuration bind $(EPINIO_APP)-rabbitmq-cfg $(EPINIO_APP)
#	Bind Service and then bind our custom Configuration - REDIS
	epinio service bind $(EPINIO_APP)_redis $(EPINIO_APP)
	./formURI.sh $(EPINIO_APP)_redis 'redis-master.$(EPINIO_NS).svc.cluster.local:6379' 'redis://user:%PASS%@%HOST%/11' > .tmp-uri
	echo -n "epinio configuration create $(EPINIO_APP)-redis-cfg REDIS_URI " > .tmp-script
	cat .tmp-uri >> .tmp-script
	bash .tmp-script
	epinio configuration bind $(EPINIO_APP)-redis-cfg $(EPINIO_APP)
#	Push the App, setting as environment variables the names of the Services and the Configurations
	rm -f .tmp-script .tmp-uri
	cat environment_dev.yml | grep -v '#dev' > environment.yml
	epinio push --name $(EPINIO_APP) \
		--env POSTGRESQL_SVC=$(EPINIO_APP)_postgresql \
		--env POSTGRESQL_CFG=$(EPINIO_APP)-postgresql-cfg \
		--env RABBITMQ_SVC=$(EPINIO_APP)_rabbitmq \
		--env RABBITMQ_CFG=$(EPINIO_APP)-rabbitmq-cfg \
		--env REDIS_SVC=$(EPINIO_APP)_redis \
		--env REDIS_CFG=$(EPINIO_APP)-redis-cfg
	rm -f environment.yml
	sleep 20

# ------------------------------------------------
# Select the namespace, delete the App and destroy all Services
# ------------------------------------------------
epinio_undeploy: epinio_target
ifndef EPINIO_APP
	$(error EPINIO_APP is undefined)
endif
	epinio app delete $(EPINIO_APP)
	$(MAKE) epinio_ds_all

# ------------------------------------------------
# Purge the entire namespace
# ------------------------------------------------
epinio_purge:
ifndef EPINIO_NS
	$(error EPINIO_NS is undefined)
endif
	epinio namespace delete $(EPINIO_NS)
