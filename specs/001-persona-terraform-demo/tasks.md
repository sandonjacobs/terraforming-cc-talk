---

description: "Task list for the persona-based Confluent Cloud Terraform demo"
---

# Tasks: Persona-Based Confluent Cloud Terraform Demo

**Input**: Design documents from `/specs/001-persona-terraform-demo/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/env-file-contract.md, quickstart.md

**Tests**: Included because plan.md specifies offline checks (`terraform validate`, `terraform test` with mocked providers, Bash tests for the env helpers, JUnit for the producer). End-to-end validation is the quickstart against a real Confluent Cloud organization.

**Implementation boundary**: Generate code and run offline checks only (`terraform fmt`, `init -backend=false`, `validate`, `test` with mocked providers, Bash tests, Maven tests). Do NOT run `terraform plan`, `apply`, or `destroy`, and do not call Confluent Cloud in any way. The project owner performs all live provisioning and testing. Any task below that mentions applying, running against an organization, or the full quickstart is for the owner, not the implementer.

**Organization**: Tasks are grouped by user story. US1 = Omar (P1), US2 = Ida (P2), US3 = Dan (P3), US4 = Ali (P4), US5 = Teresa (P5, added 2026-10-27; tasks T066 onward).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story the task belongs to (US1 to US5)
- Paths are relative to the repository root

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Clean out the Vault-based layout and create the persona skeleton

- [X] T001 Delete the obsolete Vault-based files `docker-compose.yml` and `scripts/init-vault.sh` (`cc-terraform-base/` is deleted later in T018, after its resources are migrated into Omar's workspace)
- [X] T002 [P] Update `.gitignore` to ignore `.env`, `**/.env`, `*.tfstate`, `*.tfstate.*`, `.terraform/`, `target/`, and `vault_data/`; keep `.terraform.lock.hcl` tracked
- [X] T003 [P] Create `.env.example` listing every key from `specs/001-persona-terraform-demo/contracts/env-file-contract.md` with empty placeholder values and a comment header stating the file is for documentation only and the real `.env` is gitignored
- [X] T004 [P] Create empty persona directories with placeholder `README.md` files: `omar-the-operator/`, `ida-the-integrator/`, `dan-the-data-guy/`, `ali-the-app-developer/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The env-file helpers that implement the hand-off contract. Every downstream persona depends on them.

**CRITICAL**: No downstream persona workspace (US2 to US4) can be applied until this phase is complete

- [X] T005 Write failing Bash tests in `scripts/test-env-scripts.sh` using temporary `.env` files covering: load exports `TF_VAR_<lowercased key>`; load exits non-zero naming every missing or empty key from `required-env.txt`; publish upserts `<PREFIX>_<OUTPUT_NAME uppercased>` without touching other lines; re-publishing unchanged outputs leaves the file byte-identical; unpublish removes only `<PREFIX>_*` lines; no helper prints a secret value
- [X] T006 [P] Implement `scripts/load-env.sh` (sourced, takes a persona directory, reads root `.env` and `<dir>/required-env.txt`) per the Helper commands table in `contracts/env-file-contract.md`
- [X] T007 [P] Implement `scripts/publish-env.sh` (takes persona directory and PREFIX, reads `terraform output -json`, upserts line by line, never echoes values) per `contracts/env-file-contract.md`
- [X] T008 [P] Implement `scripts/unpublish-env.sh` (takes PREFIX, removes every `<PREFIX>_*` line from `.env`) per `contracts/env-file-contract.md`
- [X] T009 Run `bash scripts/test-env-scripts.sh` and fix the helpers until all tests pass

**Checkpoint**: Env helpers verified. Persona workspaces can now be built.

---

## Phase 3: User Story 1 - Omar provisions the platform (Priority: P1) MVP

**Goal**: One workspace stands up the environment (Advanced governance), Standard Kafka cluster, and Flink compute pool in AWS us-east-1, creates per-persona service accounts, role bindings, and API keys, and publishes everything to `.env`.

**Independent Test**: Run only Omar's workspace against an empty organization; confirm the resources exist in us-east-1 and `.env` contains every `OMAR_*` key from the contract; `git status` shows `.env` untracked-and-ignored; a second apply reports no changes.

### Tests for User Story 1

- [X] T010 [P] [US1] Write a `terraform test` file `omar-the-operator/outputs.tftest.hcl` with a mocked `confluent` provider asserting that every platform and per-persona credential output named in `contracts/env-file-contract.md` exists (`organization_id`, `environment_id`, `cloud_region`, `kafka_cluster_id`, `kafka_bootstrap_endpoint`, `kafka_rest_endpoint`, `schema_registry_id`, `schema_registry_rest_endpoint`, `flink_compute_pool_id`, `flink_rest_endpoint`, and `ida_*`, `ali_*`, `dan_*` credential outputs)

### Implementation for User Story 1

- [X] T011 [P] [US1] Create `omar-the-operator/main.tf` with `required_version = ">= 1.7"`, the `confluentinc/confluent` provider constrained to `>= 2.91.0` (amended from an exact 2.25.0 pin; the committed `.terraform.lock.hcl` records the exact version), and an empty `provider "confluent" {}` block reading `CONFLUENT_CLOUD_API_KEY` and `CONFLUENT_CLOUD_API_SECRET` from the shell; use the default local backend (no `backend` block)
- [X] T012 [P] [US1] Create `omar-the-operator/variables.tf` with `cloud_provider` default `"AWS"`, `cloud_region` default `"us-east-1"`, `cc_env_display_name`, `cc_kafka_cluster_name`, `flink_max_cfu`, and `org_id` (required, no default); no secrets as defaults
- [X] T013 [US1] Create `omar-the-operator/environment.tf` with `confluent_environment` using `stream_governance { package = "ADVANCED" }` and `lifecycle { prevent_destroy = false }`, plus the `confluent_schema_registry_cluster` data source depending on the Kafka cluster
- [X] T014 [US1] Create `omar-the-operator/kafka.tf` with a Standard `confluent_kafka_cluster` (`standard {}`, `SINGLE_ZONE`, cloud and region from variables), migrating the `app-manager` and `env-manager` service accounts, role bindings, and API keys from `cc-terraform-base/kafka.tf` (keep the explanatory `depends_on` comments), and the `BACKWARD` `confluent_schema_registry_cluster_config`
- [X] T015 [US1] Create `omar-the-operator/flink.tf` with `confluent_flink_compute_pool` in the same environment and region (`max_cfu` from variable) and the `confluent_flink_region` data source needed for the Flink REST endpoint
- [X] T016 [US1] Create `omar-the-operator/persona-access.tf` with one service account per persona (Ida, Ali, Dan), each with the minimum role bindings from research.md item 6 scoped to `landing-*`, `app-*`, or `curated-*` topic prefixes, plus Kafka API keys for all three, Schema Registry API keys for Ali (read subjects) and Dan (write subjects), a Flink API key and assigner binding for Dan, and a Cloud API key for Ida's connector management; record any role-name deviations as comments and in the README
- [X] T017 [US1] Create `omar-the-operator/outputs.tf` exposing exactly the keys listed under "Keys published by Omar" in `contracts/env-file-contract.md` (output names lowercase so `publish-env.sh` yields `OMAR_<NAME>`), marking every credential output `sensitive = true`
- [X] T018 [US1] Delete `cc-terraform-base/` now that its environment, cluster, Schema Registry, and service account logic lives in `omar-the-operator/`
- [X] T019 [US1] Write `omar-the-operator/README.md` covering prerequisites (shell-exported `CONFLUENT_CLOUD_API_KEY` and `CONFLUENT_CLOUD_API_SECRET`), the run command (`terraform init && terraform apply && ../scripts/publish-env.sh . OMAR`), the teardown command (`terraform destroy && ../scripts/unpublish-env.sh OMAR`), and any least-privilege trade-offs
- [X] T020 [US1] Run `terraform init -backend=false && terraform fmt -check && terraform validate && terraform test` in `omar-the-operator/` and fix failures

**Checkpoint**: Omar's workspace validates offline; with real credentials it provisions the platform and publishes `OMAR_*` keys (quickstart step 2, Omar line).

---

## Phase 4: User Story 2 - Ida brings external data in through managed connectors (Priority: P2)

**Goal**: A workspace that reads only from `.env`, creates the `landing-orders` topic and one managed Datagen Source connector (Orders quickstart, Avro output), and publishes its outputs.

**Independent Test**: With Omar's keys in `.env`, run only Ida's workspace; no Confluent values are entered by hand; the connector reaches running state and Avro order records arrive on `landing-orders`; with `OMAR_IDA_KAFKA_API_KEY` removed, loading fails naming that key.

### Tests for User Story 2

- [X] T021 [P] [US2] Rewrite `ida-the-integrator/outputs.tftest.hcl` with mocked providers asserting outputs `orders_topic` and `orders_connector_name` exist, that the topic name contains no dots, and that the connector uses `DatagenSource`, quickstart `ORDERS`, and Avro output

### Implementation for User Story 2

- [X] T022 [P] [US2] Create `ida-the-integrator/required-env.txt` listing the platform keys and `OMAR_IDA_*` keys from the "Required keys per workspace" table in `contracts/env-file-contract.md`
- [X] T023 [P] [US2] Create `ida-the-integrator/variables.tf` declaring the lowercased `TF_VAR_*` inputs for the required keys (mark credential variables `sensitive = true`) plus `orders_topic_name` (default `landing-orders`, must start with `landing-` and contain no dots) and `orders_interval_ms` (default 1000); remove all BART variables including `bart_api_key`
- [X] T024 [US2] Create `ida-the-integrator/main.tf` with `required_version = ">= 1.7"`, the `confluentinc/confluent` provider constraint matching Omar's, and a provider block using resource-scoped settings (Kafka REST endpoint and cluster key, plus the Cloud API key for connector management) from variables
- [X] T025 [US2] Update `ida-the-integrator/topics.tf` to a single `confluent_kafka_topic` for `landing-orders`; the name MUST start with `landing-` and MUST NOT contain dots so Ida's role binding applies
- [X] T026 [US2] Replace `ida-the-integrator/connector.tf` with one managed `confluent_connector` (`orders-datagen-source`, class `DatagenSource`, `quickstart = ORDERS`, Avro output, `max.interval` from `orders_interval_ms`, `tasks.max = 1`, Ida's Kafka API key in `config_sensitive`); add Schema Registry access for Ida's `landing-*` subjects in `omar-the-operator/persona-access.tf` if the connector needs it; confirm exact property names per research.md item 8 (Verify) and record them in the README
- [X] T027 [US2] Update `ida-the-integrator/outputs.tf` to expose `orders_topic` and `orders_connector_name` so `publish-env.sh` yields `IDA_ORDERS_TOPIC` and `IDA_ORDERS_CONNECTOR_NAME`
- [X] T028 [US2] Write `ida-the-integrator/README.md` with prerequisites (no external API key), run and teardown commands (`source ../scripts/load-env.sh . && terraform apply && ../scripts/publish-env.sh . IDA`; destroy then `../scripts/unpublish-env.sh IDA`), the record rate, the connector properties confirmed for T026, and any connector role trade-off from T016
- [X] T029 [US2] Run `terraform init -backend=false && terraform fmt -check && terraform validate && terraform test` in `ida-the-integrator/` and fix failures

**Checkpoint**: Ida's workspace validates offline and runs independently once Omar's keys exist.

---

## Phase 5: User Story 3 - Dan defines schemas and Flink transformations (Priority: P3)

**Goal**: A workspace that registers Avro schemas for the demo topics and deploys Flink SQL statements writing to `curated-*` topics, reading everything from `.env`.

**Independent Test**: With the platform and at least one landing topic present, run only Dan's workspace; schemas are registered, statements run on Omar's pool and write records to `curated-*`, and an incompatible schema change is rejected. Applying it fully also needs Ali's topic name (`ALI_EVENTS_TOPIC`), which comes from US4's Terraform.

### Tests for User Story 3

- [X] T030 [P] [US3] Write `dan-the-data-guy/outputs.tftest.hcl` with mocked providers asserting output `curated_topics` exists and that one `confluent_schema` exists per `.avsc` file in `schemas/`

### Implementation for User Story 3

- [X] T031 [P] [US3] Update `dan-the-data-guy/schemas/app-events.avsc` to a generic event (`event_id`, `event_time`, `event_type`; the use case is still to be decided) matching the fields Ali's generator produces; do NOT register schemas for `landing-orders` because the connector registers it, and `curated-orders` is created by its Flink statement (research.md item 9)
- [X] T032 [P] [US3] Replace the Flink SQL files with one, `dan-the-data-guy/flink-sql/curate-orders.sql`, which flattens the `address` row of `landing-orders` into a `curated-orders` topic; field names are the Datagen Orders fields (inspect the registered schema after Ida's apply)
- [X] T033 [P] [US3] Update `dan-the-data-guy/required-env.txt` to list the platform keys, `OMAR_DAN_*` keys, `IDA_ORDERS_TOPIC`, and `ALI_EVENTS_TOPIC` per the contract
- [X] T034 [P] [US3] Create `dan-the-data-guy/variables.tf` declaring the lowercased `TF_VAR_*` inputs (credential variables `sensitive = true`) with no secrets as defaults
- [X] T035 [US3] Create `dan-the-data-guy/main.tf` with `required_version = ">= 1.7"`, the provider constraint matching Omar's, and a provider block using resource-scoped Kafka, Schema Registry, and Flink settings (organization, environment, compute pool, principal, Flink endpoint and key) from variables
- [X] T036 [US3] Create `dan-the-data-guy/schemas.tf` with `confluent_schema` resources (format `AVRO`) for subjects `<topic>-value` using `file()` on the `.avsc` files, using the topic names from variables
- [X] T037 [US3] Create `dan-the-data-guy/flink.tf` with `confluent_flink_statement` resources loading the SQL via `file()`, running as Dan's service account on Omar's compute pool, and writing only to `curated-*` topics
- [X] T038 [US3] Create `dan-the-data-guy/outputs.tf` exposing `curated_topics` as a comma-separated string so `publish-env.sh` yields `DAN_CURATED_TOPICS`
- [X] T039 [US3] Write `dan-the-data-guy/README.md` with prerequisites (Omar, Ida, and Ali applied first), run and teardown commands, and how to demonstrate the schema-compatibility rejection
- [X] T040 [US3] Run `terraform init -backend=false && terraform fmt -check && terraform validate && terraform test` in `dan-the-data-guy/` and fix failures

**Checkpoint**: Dan's workspace validates offline and, with upstream keys present, registers schemas and runs transformations.

---

## Phase 6: User Story 4 - Ali produces application data (Priority: P4)

**Goal**: A workspace that creates the application topic with scoped credentials, plus a local Java producer that sends schema-conforming Avro events.

**Independent Test**: Run Ali's workspace and microservice; records appear on `app-*` using only Ali's credentials; producing to a `landing-*` topic is denied.

### Tests for User Story 4

- [X] T041 [P] [US4] Write `ali-the-app-developer/outputs.tftest.hcl` with mocked providers asserting output `events_topic` exists and starts with `app-`
- [X] T042 [P] [US4] Write JUnit 5 tests in `ali-the-app-developer/service/src/test/java/talks/sandonjacobs/ali/EventGeneratorTest.java` asserting generated records conform to `dan-the-data-guy/schemas/app-events.avsc` and that configuration loading fails with a message naming any missing environment variable

### Implementation for User Story 4

- [X] T043 [P] [US4] Create `ali-the-app-developer/required-env.txt` listing the platform keys and `OMAR_ALI_*` keys per the contract
- [X] T044 [P] [US4] Create `ali-the-app-developer/variables.tf` declaring the lowercased `TF_VAR_*` inputs (credential variables `sensitive = true`) plus `events_topic_name` default `app-events`
- [X] T045 [US4] Create `ali-the-app-developer/main.tf` with `required_version = ">= 1.7"`, the provider constraint matching Omar's, and a provider block using the Kafka REST endpoint and Ali's cluster API key from variables
- [X] T046 [US4] Create `ali-the-app-developer/topics.tf` with the `confluent_kafka_topic` for `app-<name>`; the name MUST start with `app-` so Ali's role binding applies
- [X] T047 [US4] Create `ali-the-app-developer/outputs.tf` exposing `events_topic` so `publish-env.sh` yields `ALI_EVENTS_TOPIC`
- [X] T048 [US4] Remove the root `pom.xml`; `ali-the-app-developer/service/pom.xml` is a standalone project (amended: schema-first build)
- [X] T049 [US4] Create `ali-the-app-developer/service/pom.xml` (Java 21, Kafka clients, Confluent Avro serializer, JUnit 5, `exec-maven-plugin` main class `talks.sandonjacobs.ali.Main`, `kafka-schema-registry-maven-plugin` `download` of Dan's subject, `avro-maven-plugin` class generation, and an `-Doffline` profile that copies `dan-the-data-guy/schemas/app-events.avsc`)
- [X] T050 [US4] Implement `ali-the-app-developer/service/src/main/java/talks/sandonjacobs/ali/EventGenerator.java` producing synthetic events as the generated `AppEvent` class (no schema file path or `GenericRecord`)
- [X] T051 [US4] Implement `ali-the-app-developer/service/src/main/java/talks/sandonjacobs/ali/Main.java` and `ProducerConfigLoader.java` reading `OMAR_KAFKA_BOOTSTRAP_ENDPOINT`, `OMAR_ALI_KAFKA_API_KEY`, `OMAR_ALI_KAFKA_API_SECRET`, `OMAR_SCHEMA_REGISTRY_REST_ENDPOINT`, `OMAR_ALI_SCHEMA_REGISTRY_API_KEY`, `OMAR_ALI_SCHEMA_REGISTRY_API_SECRET`, and `ALI_EVENTS_TOPIC` from the environment, failing early naming any missing variable, with Avro serializer settings `auto.register.schemas=false` and `use.latest.version=true`, never logging secret values
- [X] T052 [US4] Write `ali-the-app-developer/README.md` with prerequisites (Omar, Ida, Ali, and Dan applied first so schemas exist), run and teardown commands, the microservice run command (`make ali-run`), and the denied-access demonstration
- [X] T053 [US4] Run `terraform init -backend=false && terraform fmt -check && terraform validate && terraform test` in `ali-the-app-developer/` and `mvn -q -f ali-the-app-developer/service/pom.xml -Doffline test`, and fix failures

**Checkpoint**: Ali's workspace and service validate offline; with upstream keys and Dan's schemas present, events flow to `app-*`.

---

## Phase 7: Make Targets for the Demo Steps

**Purpose**: One command per demo step for each persona, so the demo is easy to follow and run. Tasks only write and offline-check the Makefile; no target is executed against Confluent Cloud.

- [X] T054 Create the root `Makefile` with `SHELL := /bin/bash`, `.DEFAULT_GOAL := help`, `.PHONY` for every target, and a `help` target that lists every target with a one-line description (use `##` comments on each target)
- [X] T055 [P] Add `check` to `Makefile`: for each of the four persona directories run `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`, and `terraform test`, then `bash scripts/test-env-scripts.sh` and `mvn -q -f ali-the-app-developer/service/pom.xml -Doffline test`; this is the only target the implementer runs
- [X] T056 [P] Add `env-keys` to `Makefile` printing the key names (never values) present in `.env`, grouped by `OMAR_`, `IDA_`, `ALI_`, `DAN_`, via a small `awk`/`cut` pipeline
- [X] T057 Add explicit `omar-plan`, `omar-apply`, and `omar-destroy` targets to `Makefile` per the Make Targets table in `plan.md`: run in `omar-the-operator/`, apply then `../scripts/publish-env.sh . OMAR`, destroy then `../scripts/unpublish-env.sh OMAR`; each target first prints the persona and action
- [X] T058 [P] Add explicit `ida-plan|apply|destroy`, `ali-plan|apply|destroy`, and `dan-plan|dan-apply|dan-destroy` targets to `Makefile`: each sources `scripts/load-env.sh <dir>` (failing early on missing keys) before Terraform and publishes or unpublishes its prefix (`IDA`, `ALI`, `DAN`) after apply or destroy
- [X] T059 Add `ali-run` to `Makefile`: loads `.env` into the environment and runs `make ali-run` (`mvn -f ali-the-app-developer/service/pom.xml compile exec:java`) in the foreground
- [X] T060 Add `demo-up` (Omar, Ida, Ali, Dan apply in that order) and `demo-down` (Dan, Ali, Ida, Omar destroy in reverse order) to `Makefile`, each stopping at the first failure (amended: every apply and destroy runs with `-auto-approve`, matching the Makefile; Teresa's targets and `demo-up`/`demo-down` follow the same rule)
- [X] T061 Run `make help` and `make check` (offline only) and fix failures; do not run any other target

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T062 [P] Replace the root `README.md` (create if absent) with the demo overview: the four personas, directory map, the Make targets table, apply order (Omar, Ida, Ali, Dan, then Ali's service) and reverse teardown, and a link to `specs/001-persona-terraform-demo/quickstart.md`
- [X] T063 [P] Verify `.gitignore` and `git status`: no `.env`, state files, or credentials are tracked (SC-002); `.env.example` remains tracked with placeholder values only
- [X] T064 Run `/speckit-constitution` to PATCH-amend Principle III wording from "(Omar, then Ida, Dan, and Ali)" to "dependency order as documented in the quickstart", as recorded in plan.md Complexity Tracking
- [ ] T065 [Owner] Project owner runs the full `specs/001-persona-terraform-demo/quickstart.md` (using the Make targets) against a real Confluent Cloud organization, including idempotency, missing-key, denied-access, schema-rejection, and reverse-order teardown checks, and records any provider or role-name deviations in the affected persona README and `research.md`; the implementer does NOT perform this task

---

## Phase 9: User Story 5 - Teresa gets curated orders as an Iceberg table (Priority: P5)

**Goal**: Omar issues Teresa a topic-scoped service account with a Kafka key and a Tableflow key; a new workspace, `teresa-from-the-data-team/`, enables Tableflow on `curated-orders` with Iceberg format and Confluent-managed storage, reading only from `.env`.

**Independent Test**: With Omar's and Dan's keys in `.env`, run only Teresa's workspace; Tableflow is enabled on `curated-orders` (Iceberg, managed storage), `.env` gains `TERESA_TABLEFLOW_TOPIC` and `TERESA_TABLE_FORMATS`, a second apply reports no changes, removing `DAN_CURATED_TOPICS` makes loading fail naming it, and her credentials are denied on any other topic. Offline, this is `terraform validate` and `terraform test` in `omar-the-operator/` and `teresa-from-the-data-team/`.

**Implementation boundary**: Offline checks only (see top of file). Nothing here is applied to Confluent Cloud by the implementer. Items marked "Verify" in research.md items 14 to 17 are recorded in the READMEs for the project owner to confirm.

### Tests for User Story 5

- [X] T066 [P] [US5] Extend `omar-the-operator/outputs.tftest.hcl` so the mocked-provider test also asserts that the outputs `teresa_service_account_id`, `teresa_kafka_api_key`, `teresa_kafka_api_secret`, `teresa_tableflow_api_key`, and `teresa_tableflow_api_secret` exist, that exactly one `confluent_role_binding` for Teresa has `role_name = "ResourceOwner"` with a CRN ending in `/topic=curated-orders`, and that no Teresa binding has a CRN ending in `topic=curated-*` or `topic=*` (SC-009); add any `mock_resource` defaults the new `confluent_api_key` resources need (api_version `iam/v2`, kind `ApiKey`)
- [X] T067 [P] [US5] Write `teresa-from-the-data-team/outputs.tftest.hcl` with `mock_provider "confluent" {}` and variables for every key in `required-env.txt`, asserting that: `confluent_tableflow_topic.curated_orders.display_name == "curated-orders"`; its `table_formats` equals `["ICEBERG"]`; no `byob_aws`, `azure_data_lake_storage_gen_2`, or `google_cloud_storage` block is set (managed storage only, FR-019); outputs `tableflow_topic` and `table_formats` exist; and that a run with `curated_orders_topic` not in `dan_curated_topics` fails the topic precondition (use `expect_failures`)

### Implementation for User Story 5: Omar issues Teresa's access (FR-018)

- [X] T068 [US5] Add Teresa to `omar-the-operator/persona-access.tf` following the Ali and Dan sections: a `confluent_service_account.teresa` (display name `${var.cc_kafka_cluster_name}-teresa`, description "Teresa from the data team: enables Tableflow on curated-orders"); a `teresa_bindings` local map with `topic_owner = { role = "ResourceOwner", crn = "${local.kafka_crn}/topic=curated-orders" }` (exact topic name, not a prefix; comment that the name must match Dan's `curated_orders_topic`) and `subject_read = { role = "DeveloperRead", crn = "${local.sr_crn}/subject=*" }` (Tableflow requires read on all subjects); one `confluent_role_binding` with `for_each = local.teresa_bindings`; no `Assigner` binding and no `CloudClusterAdmin` (managed storage needs neither, research item 14)
- [X] T069 [US5] In `omar-the-operator/persona-access.tf` add Teresa's two API keys: `confluent_api_key.teresa_kafka` (cluster-scoped `managed_resource` on `confluent_kafka_cluster.kafka_cluster` with the environment block, as `ali_kafka` does, `depends_on` her role bindings) and `confluent_api_key.teresa_tableflow` (owner Teresa's service account; `managed_resource` with `id = "tableflow"`, `api_version = "tableflow/v1"`, `kind = "Tableflow"` and the environment block); add a comment that the Tableflow `managed_resource` values are a "Verify" item (research.md item 14a) to confirm against the provider docs at first live apply
- [X] T070 [US5] Add to `omar-the-operator/outputs.tf` the outputs `teresa_service_account_id`, `teresa_kafka_api_key`, `teresa_kafka_api_secret`, `teresa_tableflow_api_key`, and `teresa_tableflow_api_secret` (so `publish-env.sh` yields the `OMAR_TERESA_*` keys in `contracts/env-file-contract.md`); mark all key and secret outputs `sensitive = true`
- [X] T071 [P] [US5] Add the Teresa keys to `.env.example` as documented in `contracts/env-file-contract.md`: `OMAR_TERESA_SERVICE_ACCOUNT_ID`, `OMAR_TERESA_KAFKA_API_KEY`, `OMAR_TERESA_KAFKA_API_SECRET`, `OMAR_TERESA_TABLEFLOW_API_KEY`, `OMAR_TERESA_TABLEFLOW_API_SECRET` (under the Omar section) and `TERESA_TABLEFLOW_TOPIC`, `TERESA_TABLE_FORMATS` (a new "Published by Teresa" section), all with empty values
- [X] T072 [P] [US5] Update `omar-the-operator/README.md` to list Teresa's service account, her two roles (`ResourceOwner` on `curated-orders` only, `DeveloperRead` on all subjects), the two keys, why the binding names the exact topic (Principle IV, SC-009), and that renaming Dan's `curated_orders_topic` requires changing Omar's Teresa binding too
- [X] T073 [US5] Run `terraform init -backend=false && terraform fmt -check && terraform validate && terraform test` in `omar-the-operator/` and fix failures (do not plan or apply)

### Implementation for User Story 5: Teresa's workspace (FR-019 to FR-022)

- [X] T074 [P] [US5] Create `teresa-from-the-data-team/required-env.txt` with the header comment used by the other personas and exactly these keys: `OMAR_ENVIRONMENT_ID`, `OMAR_KAFKA_CLUSTER_ID`, `OMAR_KAFKA_REST_ENDPOINT`, `OMAR_TERESA_KAFKA_API_KEY`, `OMAR_TERESA_KAFKA_API_SECRET`, `OMAR_TERESA_TABLEFLOW_API_KEY`, `OMAR_TERESA_TABLEFLOW_API_SECRET`, `DAN_CURATED_TOPICS` (the last one makes `load-env.sh` stop early if Dan has not applied, FR-020, FR-022)
- [X] T075 [P] [US5] Create `teresa-from-the-data-team/variables.tf` declaring one lowercased variable per key in `required-env.txt` (`omar_environment_id`, `omar_kafka_cluster_id`, `omar_kafka_rest_endpoint`, `omar_teresa_kafka_api_key`, `omar_teresa_kafka_api_secret`, `omar_teresa_tableflow_api_key`, `omar_teresa_tableflow_api_secret`, `dan_curated_topics`) with `sensitive = true` on every key and secret and no secrets as defaults, plus `curated_orders_topic` (default `"curated-orders"`, validation: starts with `curated-` and contains no dots, matching Dan's variable and FR-010a)
- [X] T076 [US5] Create `teresa-from-the-data-team/main.tf` with `required_version = ">= 1.7"`, the `confluentinc/confluent` provider constrained to `>= 2.91.0` like the other workspaces, and a `provider "confluent"` block setting `kafka_rest_endpoint`, `kafka_api_key`, `kafka_api_secret` (Teresa's Kafka key), and `tableflow_api_key` and `tableflow_api_secret` (Teresa's Tableflow key); do not set organization-level credentials; default local backend; a header comment that Teresa uses only resource-scoped credentials, like Dan's `main.tf`
- [X] T077 [US5] Create `teresa-from-the-data-team/tableflow.tf` with (a) a `data "confluent_kafka_topic" "curated_orders"` (topic name `var.curated_orders_topic`, `kafka_cluster { id = var.omar_kafka_cluster_id }`, `rest_endpoint` from the variable, credentials from Teresa's Kafka key), (b) a `terraform_data` or `check`-style precondition that `var.curated_orders_topic` appears in `split(",", var.dan_curated_topics)` with the error message "curated-orders is not in DAN_CURATED_TOPICS: apply Dan's workspace first" (FR-022), and (c) `resource "confluent_tableflow_topic" "curated_orders"` with `display_name = data.confluent_kafka_topic.curated_orders.topic_name`, `table_formats = ["ICEBERG"]`, an empty `managed_storage {}` block (Confluent-managed storage, no bucket or provider integration, FR-019), `environment { id = var.omar_environment_id }`, `kafka_cluster { id = var.omar_kafka_cluster_id }`, and `credentials { key = var.omar_teresa_kafka_api_key, secret = var.omar_teresa_kafka_api_secret }`; leave `retention_ms` at its default; add a comment pointing to research.md item 15 for the `managed_storage {}` "Verify"
- [X] T078 [US5] Create `teresa-from-the-data-team/outputs.tf` with the header comment used by Dan's (prefix `TERESA_`, uppercased) and two outputs: `tableflow_topic` (the enabled topic name) and `table_formats` (`join(",", confluent_tableflow_topic.curated_orders.table_formats)`), so `publish-env.sh` yields `TERESA_TABLEFLOW_TOPIC` and `TERESA_TABLE_FORMATS`; neither is sensitive
- [X] T079 [US5] Write `teresa-from-the-data-team/README.md` following Dan's README pattern: who Teresa is and what she gets (Iceberg table of `curated-orders`, Confluent-managed storage, no bucket); prerequisites (Omar, Ida, Ali, and Dan applied first so `curated-orders` exists); run command (`make teresa-apply`, which is `source ../scripts/load-env.sh . && terraform apply && ../scripts/publish-env.sh . TERESA`); teardown (`make teresa-destroy`, run before Dan's destroy); what to expect (the table shows as syncing and is empty until records reach the topic, a few minutes for low-throughput topics); the least-privilege scope; and the "Verify" items from research.md 14 to 17 for the project owner to confirm at first live apply
- [X] T080 [US5] Run `terraform init -backend=false && terraform fmt -check && terraform validate && terraform test` in `teresa-from-the-data-team/` and fix failures (do not plan or apply; use `-backend=false` and the mocked provider only)

**Checkpoint**: Omar's and Teresa's workspaces validate offline; with real credentials and Dan applied, Teresa's workspace enables Tableflow on `curated-orders`.

---

## Phase 10: Make Targets, Docs, and Validation for Teresa

**Purpose**: Wire Teresa into the demo commands and documentation. Offline only.

- [X] T081 [US5] Update the root `Makefile`: add `teresa-from-the-data-team` to `PERSONAS` (so `make check` covers it); add `teresa-plan teresa-apply teresa-destroy` to `.PHONY`; add a Teresa section after Dan's (heading "Teresa from the data team (step 5): serves the data. Tableflow turns curated-orders into an Iceberg table") with `teresa-plan`, `teresa-apply` (publishes `TERESA`) and `teresa-destroy` (unpublishes `TERESA`) following Dan's targets exactly, using `$(call with_env,teresa-from-the-data-team,...)`; update `demo-up` to apply Omar, Ida, Ali, Dan, then Teresa, and `demo-down` to destroy Teresa, Dan, Ali, Ida, then Omar; add `TERESA` to the prefix list in `env-keys`; update the "Start here" heading to "Omar → Ida → Ali → Dan → Teresa (then Ali's producer)"
- [X] T082 [P] [US5] Update the root `README.md`: add Teresa to the persona table and directory map, the Make targets table, the apply order (Omar, Ida, Ali, Dan, Teresa) and the reverse teardown, and a link to `specs/001-persona-terraform-demo/quickstart.md`
- [X] T083 [P] [US5] Update `PROJECT_OVERVIEW.md`: add "Teresa from the data team" to the cast table (Tableflow on `curated-orders` as an Iceberg table, Confluent-managed storage), add `teresa-from-the-data-team` to the architecture mermaid diagram (an arrow from Kafka's `curated-orders` to an "Iceberg table" node via Tableflow), update "four personas" wording, the topic naming and apply-order lists, and the `make demo-up`/`demo-down` descriptions
- [X] T084 [US5] Run `make help` and `make check` (offline only) and fix failures; confirm `make help` lists the three `teresa-*` targets and `make check` runs Teresa's workspace; do not run any other target
- [X] T085 [P] [US5] Verify `.gitignore` and `git status`: no `.env`, state, or credentials are tracked (SC-002) and `teresa-from-the-data-team/` contains no `.tfstate` or `.terraform/` content staged
- [ ] T086 [Owner] [US5] Project owner runs the Teresa steps of `specs/001-persona-terraform-demo/quickstart.md` live (after `make demo-up`): confirm Tableflow is enabled on `curated-orders` as Iceberg with managed storage and the table fills after records flow (SC-008); re-run `make teresa-apply` for "No changes"; remove `DAN_CURATED_TOPICS` from `.env` and confirm `make teresa-plan` fails naming it; confirm Teresa's Kafka key is denied on other topics (SC-009); confirm `make teresa-destroy` then `make demo-down` leave nothing behind; record the research.md "Verify" outcomes (items 14 to 17: Tableflow key `managed_resource` values, binding on a not-yet-existing topic, `managed_storage {}` syntax, Flink-created schema acceptance, org entitlement) in `teresa-from-the-data-team/README.md`; the implementer does NOT perform this task

---

## Phase 11: Teresa's Demo Notebook (User Story 5 extension, FR-023 to FR-028)

**Goal**: A local, read-only Jupyter notebook in `teresa-from-the-data-team/notebook/` that reads the `curated-orders` Iceberg table through the Tableflow REST catalog and shows a chart and a table of orders, configured only from `.env`, with offline checks that keep secrets and saved outputs out of the repository.

**Independent Test**: Offline: `python3 -m unittest discover -s teresa-from-the-data-team/notebook` and `python3 teresa-from-the-data-team/notebook/check_notebook.py teresa-from-the-data-team/notebook/curated_orders.ipynb` pass, and `make check` stays green. Live (owner, T100): `make teresa-notebook` opens the notebook and, with a populated table, shows the chart and recent orders.

**Implementation boundary**: Offline only. Do NOT run `pip install`, create the virtualenv, start Jupyter, or call the Tableflow endpoint; the helper and checks use only the Python standard library so they run without installs. `requirements.txt` is written but not installed. Unconfirmed items are research.md items 18 to 21 ("Verify").

**Constraints to follow** (plan.md "Teresa's Notebook", research.md 18 to 21): the notebook adds no Terraform, roles, or `.env` keys; the helper reads only `OMAR_ORGANIZATION_ID`, `OMAR_ENVIRONMENT_ID`, `OMAR_KAFKA_CLUSTER_ID`, `OMAR_CLOUD_REGION`, `OMAR_TERESA_TABLEFLOW_API_KEY`, `OMAR_TERESA_TABLEFLOW_API_SECRET`, plus the optional overrides `TABLEFLOW_CATALOG_ENDPOINT` and `TABLEFLOW_CATALOG_WAREHOUSE`.

### Tests for the notebook (write first; they fail until T089 and T090 exist)

- [X] T087 [P] [US5] Write `teresa-from-the-data-team/notebook/test_catalog_config.py` using `unittest` with a fake environment dict (no real values, no network, no files) asserting that `catalog_config.build_settings(env)` returns: `uri` equal to `https://tableflow.us-east-2.aws.confluent.cloud/iceberg/catalog/organizations/<org>/environments/<env>` from `OMAR_CLOUD_REGION`, `OMAR_ORGANIZATION_ID`, `OMAR_ENVIRONMENT_ID`; `credential` equal to `<OMAR_TERESA_TABLEFLOW_API_KEY>:<OMAR_TERESA_TABLEFLOW_API_SECRET>`; the header `X-Iceberg-Access-Delegation` equal to `vended-credentials`; and a `table_identifier` equal to `(<OMAR_KAFKA_CLUSTER_ID>, "curated-orders")`; that `TABLEFLOW_CATALOG_ENDPOINT` replaces `uri` and `TABLEFLOW_CATALOG_WAREHOUSE` sets `warehouse` (absent otherwise); that a missing or empty required key raises `catalog_config.MissingConfig` whose message names EVERY missing key at once and never contains the key or secret values; that `repr()` and `str()` of the settings object do not contain the secret; and that `friendly_message(kind)` returns a plain sentence (no "Traceback") for `"empty"` and `"missing"` that mentions waiting a few minutes and re-running
- [X] T088 [P] [US5] Write `teresa-from-the-data-team/notebook/test_check_notebook.py` using `unittest` and `tempfile` that writes sample notebooks to a temp directory and asserts `check_notebook.check(path)` returns no problems for a clean nbformat-4 notebook and returns problems naming the cell for: invalid JSON; `nbformat` not 4; a code cell with non-empty `outputs`; a code cell with a non-null `execution_count`; a cell source containing a string shaped like an API key assignment (for example `api_key = "ABCDEFGHIJKLMNOP"`), a Confluent resource ID (`lkc-` or `env-` followed by letters or digits), an organization UUID, or the text `Bearer `; and that the problem text never echoes the offending secret-looking value in full

### Implementation for the notebook

- [X] T089 [US5] Create `teresa-from-the-data-team/notebook/catalog_config.py` (standard library only; module docstring explaining it is the notebook's only logic and that research.md items 18 and 19 are "Verify"): constants for the required keys; `class MissingConfig(Exception)`; `build_settings(env)` returning a small immutable object with `catalog_name`, `properties` (a dict with `type` `rest`, `uri`, `credential`, `header.X-Iceberg-Access-Delegation`, and `warehouse` only when overridden) and `table_identifier`; `load_settings()` calling it on `os.environ`; a `__repr__` that masks the credential; `friendly_message(kind)` for `"empty"` and `"missing"`; and no printing or logging of secret values. Keep the endpoint form, the namespace choice (cluster ID), and the table name each in one place so a Verify fix is one line
- [X] T090 [US5] Create `teresa-from-the-data-team/notebook/check_notebook.py` (standard library only, `python3 check_notebook.py <notebook> [...]`): `check(path)` parses the file as JSON, requires `nbformat == 4` and a `cells` list, flags any code cell with non-empty `outputs` or non-null `execution_count`, and scans every cell source and output for secret-looking text (key/secret assignments with a long literal, `lkc-`/`env-` IDs, UUIDs, `Bearer `); `main()` prints one line per problem with the cell index and rule but never the matched value, and exits non-zero when any problem is found
- [X] T091 [P] [US5] Create `teresa-from-the-data-team/notebook/requirements.txt` with exactly: `pyiceberg[pyarrow]>=0.9`, `pandas>=2.2`, `matplotlib>=3.9`, `jupyterlab>=4.2` and a header comment saying the notebook's offline checks need none of these and that Python 3.11 to 3.13 is recommended (research.md item 21); do not install them
- [X] T092 [US5] Create `teresa-from-the-data-team/notebook/curated_orders.ipynb` as a valid nbformat 4 notebook with cleared outputs and null execution counts, containing: a markdown title cell (Teresa's view of `curated-orders` through Tableflow, read-only); a code cell that imports `catalog_config`, calls `load_settings()` and prints only the catalog name and table (never the credential), turning `MissingConfig` into a printed message listing the missing keys; a code cell that opens the catalog with `pyiceberg.catalog.load_catalog` and loads the table, catching a missing table or catalog error and printing `friendly_message("missing")` instead of a trace; a code cell that scans to pandas and, if there are no rows, prints `friendly_message("empty")` and stops; a code cell that draws a bar chart of order counts by `state` with matplotlib; and a code cell that shows the 10 most recent orders by `ordertime` as a table. The field names `state` and `ordertime` come from Dan's `curate-orders.sql`
- [X] T093 [US5] Run `python3 -m unittest discover -s teresa-from-the-data-team/notebook -p "test_*.py"` and `python3 teresa-from-the-data-team/notebook/check_notebook.py teresa-from-the-data-team/notebook/curated_orders.ipynb` and fix failures (offline; do not install packages or start Jupyter)

### Make targets, docs, and validation for the notebook

- [X] T094 [US5] Add `teresa-notebook` to the root `Makefile` (and to `.PHONY`, with a `##` help line in Teresa's section) that: fails early with "No .env found. Apply the personas first." if `.env` is missing; creates `teresa-from-the-data-team/notebook/.venv` with `$(PYTHON)` (a variable defaulting to `python3`, overridable) if it does not exist; runs `.venv/bin/pip install -q -r requirements.txt`; exports `.env` with `set -a; source .env; set +a`; runs `.venv/bin/python -c` using `catalog_config.load_settings()` first so any missing keys are named before Jupyter starts; then launches `.venv/bin/jupyter lab curated_orders.ipynb` from the notebook directory. Echo "Teresa from the data team: notebook" first. Do NOT run this target during implementation
- [X] T095 [US5] Extend the `check` target in the root `Makefile` to also run, after Teresa's Terraform checks, `python3 -m unittest discover -s teresa-from-the-data-team/notebook -p "test_*.py"` and `python3 teresa-from-the-data-team/notebook/check_notebook.py teresa-from-the-data-team/notebook/curated_orders.ipynb` under a heading line `== teresa notebook (stdlib only, offline)`; these need no installed packages
- [X] T096 [P] [US5] Add a "Notebook" section to `teresa-from-the-data-team/README.md`: what it shows; `make teresa-notebook` (first run builds `notebook/.venv`, needs network for pip once, Python 3.11 to 3.13 recommended, `PYTHON=python3.12 make teresa-notebook` to choose one); that it reads only `.env`; the optional `TABLEFLOW_CATALOG_ENDPOINT` and `TABLEFLOW_CATALOG_WAREHOUSE` overrides and when to use them; the empty-table message and what to do; the rule to clear outputs before commit (the hygiene check enforces it); and the "Verify" items 18 to 21 from research.md for the owner
- [X] T097 [P] [US5] Update the root `README.md` and `PROJECT_OVERVIEW.md` briefly: add `make teresa-notebook` (open Teresa's chart of `curated-orders`) after the Teresa step in each run list, and mention the notebook in Teresa's row and, in `PROJECT_OVERVIEW.md`, in the architecture diagram label for the Iceberg table
- [X] T098 [P] [US5] Verify `.gitignore` ignores `**/.venv/`, `.ipynb_checkpoints/`, and `__pycache__/` (already added by the plan; add anything missing), and that `git status` after T093 shows no `__pycache__` or checkpoint files
- [X] T099 [US5] Run `make help` and `make check` (offline only) and fix failures; confirm `make help` lists `teresa-notebook` and that `make check` runs the notebook's unit tests and hygiene check; do not run `make teresa-notebook`
- [ ] T100 [Owner] [US5] Project owner runs `make teresa-notebook` after `make demo-up` and the first rows reach `curated-orders`: confirm the chart and recent-orders table appear (SC-010); confirm an empty or not-yet-materialized table gives the friendly message (SC-011); if the derived endpoint or catalog name is wrong, set `TABLEFLOW_CATALOG_ENDPOINT` and `TABLEFLOW_CATALOG_WAREHOUSE`, then record the working values' form and the outcomes for research.md items 18 to 21 (URL form, warehouse, namespace, whether `ResourceOwner` can read, wheel availability on your Python) in `research.md` and `teresa-from-the-data-team/README.md`, and fix the helper's defaults to match; confirm `git status` shows no saved notebook outputs (SC-012); the implementer does NOT perform this task
- [X] T101 [US5] Analysis fixes for the notebook (N1 to N7): display the recent-orders table explicitly in `curated_orders.ipynb`; install `requirements.txt` only when the venv is new or the file changed; prefer Python 3.13/3.12/3.11 in the Makefile; export only the notebook's own keys from `.env` via `catalog_config.py --keys`; add a read-only (no catalog writes) rule to `check_notebook.py` with tests; use "warehouse" consistently; add the notebook row to `contracts/env-file-contract.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies. The removal of `cc-terraform-base/` happens later at T018.
- **Foundational (Phase 2)**: Depends on Setup. Blocks US2, US3, and US4. US1 can be authored in parallel (it only needs `publish-env.sh` at run time).
- **User Stories (Phase 3+)**: Priority order P1 to P4, but see below.
- **Make Targets (Phase 7)**: Depends on the persona workspaces existing (paths and output names); `check` needs all four workspaces and the Maven module.
- **Polish (Phase 8)**: Depends on all desired stories and the Make targets.
- **Teresa (Phases 9 and 10)**: Depend on Phases 1 to 8 being done. T068 to T070 (Omar's Teresa access) block T074 to T080 only at run time; authoring can overlap because the key names are fixed in `contracts/env-file-contract.md`. Phase 10 depends on Phase 9.
- **Teresa's notebook (Phase 11)**: Depends on Phases 9 and 10 (the Makefile and README it extends). T087 and T088 come before T089 and T090. T092 depends on T089 (it imports the helper); T093 depends on T087 to T092; T094 and T095 depend on T089 and T090; T099 depends on all of T087 to T098. The notebook needs nothing from Terraform at author time; at run time it needs Teresa's keys and a populated table.

### User Story Dependencies

- **US1 (Omar)**: No story dependencies. MVP.
- **US2 (Ida)**: Needs Omar's keys at run time; authoring is independent after Foundational.
- **US4 (Ali) Terraform (T043 to T047)**: Needs Omar's keys at run time; independent of Ida.
- **US3 (Dan)**: Needs Omar, Ida, and Ali's published keys at run time; authoring is independent. Live-apply order is Omar, Ida, Ali, then Dan.
- **US4 microservice (T048 to T053)**: Needs Dan's schemas registered before it can produce.
- **US5 (Teresa)**: Needs Omar's `OMAR_TERESA_*` keys (T068 to T070) and Dan's topic (`DAN_CURATED_TOPICS`) at run time. Live-apply order is Omar, Ida, Ali, Dan, then Teresa; teardown is Teresa first, then Dan, Ali, Ida, Omar. Dan's workspace is not changed (FR-021).

### Within Each User Story

- Tests are written first and expected to fail until the matching Terraform or code exists
- Variables and provider config before resources; resources before outputs; README and offline validation last

### Parallel Opportunities

- T002, T003, T004 in Setup
- T006, T007, T008 in Foundational (after T005)
- T010, T011, T012 in US1; US2, US3, and US4 authoring can proceed in parallel once Foundational is done
- T031 to T034 in US3; T041 to T044 in US4
- T055 and T056 in Make Targets; T062 and T063 in Polish
- T066 and T067 (tests), T071 and T072 (docs and `.env.example`), and T074 and T075 in US5; T082, T083 and T085 in Phase 10
- T087 and T088 (notebook tests), T091 (requirements), T096, T097, and T098 in Phase 11

---

## Parallel Example: User Story 3

```bash
# Launch together (different files):
Task: "Create illustrative Avro schemas in dan-the-data-guy/schemas/"
Task: "Create Flink SQL files in dan-the-data-guy/flink-sql/"
Task: "Create dan-the-data-guy/required-env.txt"
Task: "Create dan-the-data-guy/variables.tf"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1 (Omar)
4. **STOP and VALIDATE**: offline checks pass (`make check`); the project owner then runs `make omar-apply`, confirms resources and `.env` keys, confirms a second apply shows no changes, and runs `make omar-destroy`

### Teresa Increment (User Story 5)

1. Write the tests (T066, T067), then Omar's access (T068 to T073), validate offline
2. Build Teresa's workspace (T074 to T080), validate offline
3. Wire the Makefile and docs (T081 to T085), run `make check`
4. **STOP**: the project owner runs T086 live; the implementer does not apply anything

### Notebook Increment (Phase 11)

1. Write the two test files (T087, T088); they fail until the modules exist
2. Implement the helper and the hygiene check (T089, T090), then the requirements and notebook (T091, T092); run T093
3. Add the Make targets, docs, and `check` wiring (T094 to T098); run `make check` (T099)
4. **STOP**: the owner runs T100 live; the implementer installs nothing and starts nothing

### Incremental Delivery

1. Setup and Foundational, then US1 (platform foundation) and validate
2. Add US2 (Ida) and validate; then US4 Terraform (Ali's topics)
3. Add US3 (Dan) and validate, then US4's microservice
4. Add Make targets and Polish; the project owner then runs the quickstart live (T065)

---

## Notes

- [P] tasks touch different files and have no dependency on incomplete tasks
- Role names, cluster networking, and connector-management permissions are flagged "Verify" in research.md; record outcomes in the relevant README
- Commit after each task or logical group
- Never commit a real `.env`; only `.env.example`
