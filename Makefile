# One command per demo step, per persona. See README.md and
# specs/001-persona-terraform-demo/quickstart.md.
#
# Live targets (*-plan, *-apply, *-destroy, ali-run, demo-up, demo-down) talk to Confluent Cloud.
# `make check` is offline and safe to run any time.
#
# Lines starting with `##@` are group headings and targets with a trailing `## text` are listed by
# `make help`, in the order they appear in this file.

SHELL := /bin/bash
.DEFAULT_GOAL := help

PERSONAS := omar-the-operator ida-the-integrator ali-the-app-developer dan-the-data-guy teresa-from-the-data-team

# Load the persona's required keys from .env (fails early naming any missing key), then run the
# given command from the persona's directory.
define with_env
set -euo pipefail; source scripts/load-env.sh $(1); cd $(1); $(2)
endef

ALI_POM := ali-the-app-developer/service/pom.xml

# Teresa's notebook runs in its own virtualenv. The data libraries may not have wheels for the newest
# Python yet, so prefer 3.13, 3.12, or 3.11; override with `PYTHON=python3.12 make teresa-notebook`.
PYTHON ?= $(shell command -v python3.13 || command -v python3.12 || command -v python3.11 || command -v python3)
TERESA_NB := teresa-from-the-data-team/notebook

.PHONY: help check env-keys \
	omar-plan omar-apply omar-destroy \
	ida-plan ida-apply ida-destroy \
	ali-plan ali-apply ali-destroy ali-schemas ali-run \
	dan-plan dan-apply dan-destroy \
	teresa-plan teresa-apply teresa-destroy teresa-notebook \
	demo-up demo-down

##@ 🧭 Start here: the cast runs in this order, Omar → Ida → Ali → Dan → Teresa (then Ali's producer)

help: ## 🙋 Show this menu
	@awk 'BEGIN {FS = ":.*## "; printf "\n\033[1m🏗️  Terraforming Confluent Cloud: one make target per persona\033[0m\n"} \
	  /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} \
	  /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2} \
	  END {printf "\n"}' $(MAKEFILE_LIST)

##@ 🛠️  Omar the Operator (step 1): runs the platform. Environment, Enterprise cluster, Flink pool, and everyone's credentials

omar-plan: ## 👀 Omar previews the platform
	@echo "🛠️  Omar the Operator: plan"
	@cd omar-the-operator && terraform init -input=false >/dev/null && terraform plan

omar-apply: ## 🏗️  Omar builds the platform and publishes OMAR_* keys to .env
	@echo "🛠️  Omar the Operator: apply"
	@set -euo pipefail; cd omar-the-operator; terraform init -input=false >/dev/null; terraform apply -auto-approve; \
	cd ..; scripts/publish-env.sh omar-the-operator OMAR

omar-destroy: ## 💥 Omar tears down the platform and clears OMAR_* keys (do this last)
	@echo "🛠️  Omar the Operator: destroy"
	@set -euo pipefail; cd omar-the-operator; terraform destroy -auto-approve; cd ..; scripts/unpublish-env.sh OMAR

##@ 🔌 Ida the Integrator (step 2): brings data in. A Datagen connector and its landing topic

ida-plan: ## 👀 Ida previews the orders topic and connector
	@echo "🔌 Ida the Integrator: plan"
	@$(call with_env,ida-the-integrator,terraform init -input=false >/dev/null && terraform plan)

ida-apply: ## 🛒 Ida starts the orders connector and publishes IDA_* keys
	@echo "🔌 Ida the Integrator: apply"
	@$(call with_env,ida-the-integrator,terraform init -input=false >/dev/null && terraform apply -auto-approve)
	@scripts/publish-env.sh ida-the-integrator IDA

ida-destroy: ## 💥 Ida removes the connector and topic, clears IDA_* keys
	@echo "🔌 Ida the Integrator: destroy"
	@$(call with_env,ida-the-integrator,terraform destroy -auto-approve)
	@scripts/unpublish-env.sh IDA

##@ 📱 Ali the App Developer (step 3): builds the app. Its topic, plus a local Java producer

ali-plan: ## 👀 Ali previews the app topic
	@echo "📱 Ali the App Developer: plan"
	@$(call with_env,ali-the-app-developer,terraform init -input=false >/dev/null && terraform plan)

ali-apply: ## 🧱 Ali creates the app topic and publishes ALI_* keys
	@echo "📱 Ali the App Developer: apply"
	@$(call with_env,ali-the-app-developer,terraform init -input=false >/dev/null && terraform apply -auto-approve)
	@scripts/publish-env.sh ali-the-app-developer ALI

ali-schemas: ## 📥 Ali downloads Dan's schema from Schema Registry and generates the Java classes
	@echo "📱 Ali the App Developer: fetch schemas and generate classes"
	@set -euo pipefail; \
	[ -f .env ] || { echo "No .env found. Apply the personas first."; exit 1; }; \
	set -a; source .env; set +a; \
	mvn -q -f $(ALI_POM) generate-sources

ali-run: ## 🚀 Ali runs the local producer (needs Dan applied first; Ctrl-C to stop)
	@echo "📱 Ali the App Developer: run the producer"
	@set -euo pipefail; \
	[ -f .env ] || { echo "No .env found. Apply the personas first."; exit 1; }; \
	set -a; source .env; set +a; \
	mvn -q -f $(ALI_POM) compile exec:java

ali-destroy: ## 💥 Ali removes the app topic, clears ALI_* keys (stop the producer first)
	@echo "📱 Ali the App Developer: destroy"
	@$(call with_env,ali-the-app-developer,terraform destroy -auto-approve)
	@scripts/unpublish-env.sh ALI

##@ 📊 Dan the Data Guy (step 4): shapes the data. Avro schema and Flink SQL statements

dan-plan: ## 👀 Dan previews the schema and Flink statements
	@echo "📊 Dan the Data Guy: plan"
	@$(call with_env,dan-the-data-guy,terraform init -input=false >/dev/null && terraform plan)

dan-apply: ## 🌊 Dan registers the schema, starts the Flink statements, publishes DAN_* keys
	@echo "📊 Dan the Data Guy: apply"
	@$(call with_env,dan-the-data-guy,terraform init -input=false >/dev/null && terraform apply -auto-approve)
	@scripts/publish-env.sh dan-the-data-guy DAN

dan-destroy: ## 💥 Dan stops the statements and removes the schema, clears DAN_* keys (after Teresa)
	@echo "📊 Dan the Data Guy: destroy"
	@if [ -f .env ] && grep -q '^TERESA_' .env; then \
	  echo "Teresa's Tableflow still reads curated-orders (TERESA_* keys are in .env). Run 'make teresa-destroy' first."; exit 1; \
	fi
	@$(call with_env,dan-the-data-guy,terraform destroy -auto-approve)
	@scripts/unpublish-env.sh DAN

##@ 🧊 Teresa from the data team (step 5): serves the data. Tableflow turns curated-orders into an Iceberg table

teresa-plan: ## 👀 Teresa previews the Tableflow table
	@echo "🧊 Teresa from the data team: plan"
	@$(call with_env,teresa-from-the-data-team,terraform init -input=false >/dev/null && terraform plan)

teresa-apply: ## 🧊 Teresa enables Tableflow on curated-orders and publishes TERESA_* keys
	@echo "🧊 Teresa from the data team: apply"
	@$(call with_env,teresa-from-the-data-team,terraform init -input=false >/dev/null && terraform apply -auto-approve)
	@scripts/publish-env.sh teresa-from-the-data-team TERESA

teresa-notebook: ## 📓 Teresa opens a notebook charting curated-orders from the Iceberg table (pip needs network once)
	@echo "🧊 Teresa from the data team: notebook"
	@set -euo pipefail; \
	[ -f .env ] || { echo "No .env found. Apply the personas first."; exit 1; }; \
	[ -d $(TERESA_NB)/.venv ] || $(PYTHON) -m venv $(TERESA_NB)/.venv; \
	stamp=$(TERESA_NB)/.venv/.requirements-installed; \
	if [ ! "$$stamp" -nt $(TERESA_NB)/requirements.txt ]; then \
	  $(TERESA_NB)/.venv/bin/pip install -q -r $(TERESA_NB)/requirements.txt && touch "$$stamp"; \
	fi; \
	for key in $$(python3 $(TERESA_NB)/catalog_config.py --keys); do \
	  line=$$(grep -E "^$$key=" .env | tail -n 1 || true); \
	  [ -z "$$line" ] || export "$$key=$${line#*=}"; \
	done; \
	cd $(TERESA_NB); \
	.venv/bin/python catalog_config.py; \
	.venv/bin/jupyter lab curated_orders.ipynb

teresa-destroy: ## 💥 Teresa disables Tableflow, clears TERESA_* keys (do this before Dan)
	@echo "🧊 Teresa from the data team: destroy"
	@$(call with_env,teresa-from-the-data-team,terraform destroy -auto-approve)
	@scripts/unpublish-env.sh TERESA

##@ 🎬 The whole show: every persona in order, each apply runs with -auto-approve

# Every apply/destroy runs with -auto-approve; nothing stops to ask for confirmation.
demo-up: ## 🎉 Omar, Ida, Ali, Dan, then Teresa in order (stops at the first failure)
	$(MAKE) omar-apply
	$(MAKE) ida-apply
	$(MAKE) ali-apply
	$(MAKE) dan-apply
	$(MAKE) teresa-apply
	@echo "🎉 Demo is up. Run 'make ali-run' to start Ali's producer."

demo-down: ## 🧹 Teresa, Dan, Ali, Ida, then Omar in reverse (stop Ali's producer first)
	$(MAKE) teresa-destroy
	$(MAKE) dan-destroy
	$(MAKE) ali-destroy
	$(MAKE) ida-destroy
	$(MAKE) omar-destroy

##@ 🔦 Backstage: safe, offline helpers that never touch Confluent Cloud

check: ## ✅ Run fmt, validate, mocked tests, env-script tests and JUnit (offline)
	@set -euo pipefail; \
	for d in $(PERSONAS); do \
	  echo "== $$d"; \
	  (cd $$d && terraform fmt -check && terraform init -backend=false -input=false >/dev/null && terraform validate && terraform test); \
	done; \
	echo "== Teresa owns Tableflow (FR-021): Dan's workspace must not declare it"; \
	if grep -rn --include='*.tf' 'confluent_tableflow_topic' dan-the-data-guy; then echo "Dan's workspace must not manage Tableflow"; exit 1; fi; \
	echo "== teresa notebook (stdlib only, offline)"; \
	python3 -m unittest discover -s $(TERESA_NB) -p "test_*.py"; \
	python3 $(TERESA_NB)/check_notebook.py $(TERESA_NB)/curated_orders.ipynb; \
	echo "== scripts"; bash scripts/test-env-scripts.sh; \
	echo "== ali-the-app-developer/service (schema copied from Dan's directory, no Schema Registry)"; mvn -q -f $(ALI_POM) -Doffline test

env-keys: ## 🔑 List the key names in .env by persona (never the values)
	@if [ ! -f .env ]; then echo "No .env yet. Run 'make omar-apply' first."; exit 0; fi; \
	for p in OMAR IDA ALI DAN TERESA; do \
	  echo "$$p:"; grep -E "^$${p}_[A-Z0-9_]*=" .env | cut -d= -f1 | sed 's/^/  /' || true; \
	done
