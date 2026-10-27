# Implementation Plan: Persona-Based Confluent Cloud Terraform Demo

**Branch**: `001-persona-terraform-demo` | **Date**: 2026-10-21 (amended 2026-10-27 for Teresa) | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-persona-terraform-demo/spec.md`

## Summary

Replace the single `cc-terraform-base/` workspace (and its Vault wiring) with five independent
Terraform workspaces, one per persona: `omar-the-operator`, `ida-the-integrator`,
`dan-the-data-guy`, `ali-the-app-developer`, and `teresa-from-the-data-team`. Omar provisions the platform foundation
(environment with Advanced governance, Standard Kafka cluster, Flink compute pool, all in AWS
us-east-2) plus a least-privilege service account and API keys per downstream persona. All
hand-off values flow through one gitignored root `.env` file: small shell helpers load it into
`TF_VAR_*` variables before each run and upsert each persona's Terraform outputs back into it.
Ida adds a managed connector and landing topic, Ali adds application topics and a local Java
producer, and Dan registers Avro schemas and deploys Flink SQL statements. Teresa (added by
User Story 5) enables Tableflow on Dan's `curated-orders` topic so it is available as an Iceberg
table in Confluent-managed storage; Omar issues her a topic-scoped service account and her own
Kafka and Tableflow API keys. A local Jupyter notebook beside her workspace then reads that table
through the Tableflow Iceberg REST catalog with PyIceberg and charts the orders for the talk; it is
read-only, adds no Terraform, roles, or keys, and takes all its configuration from `.env`. A root `Makefile`
gives each persona simple targets (plan, apply, destroy) so the demo steps are easy to read and
run. See [research.md](research.md) for the decisions behind this approach.

**Implementation boundary**: Implementation generates code and runs only offline checks
(`terraform fmt`, `init -backend=false`, `validate`, `test` with mocked providers, Bash tests, Maven
tests). It MUST NOT run `terraform plan`, `apply`, or `destroy`, or otherwise create, change, or
call anything in Confluent Cloud. The project owner runs all live provisioning and testing.

## Technical Context

**Language/Version**: HCL (Terraform >= 1.7); Bash for env helpers; Java 21 for Ali's microservice; Python 3.11 to 3.13 for Teresa's notebook (3.14 wheels for the data libraries are a Verify item)

**Primary Dependencies**: `confluentinc/confluent` Terraform provider (minimum 2.91.0, exact version
recorded in each workspace's committed `.terraform.lock.hcl`); Apache Kafka clients + Confluent Avro
serializer (Java, built with Maven); PyIceberg (with PyArrow), pandas, matplotlib, and JupyterLab for
Teresa's notebook, installed into a local virtualenv from `requirements.txt`

**Storage**: Local Terraform state per persona directory (gitignored); one gitignored `.env` file
at the repository root as the hand-off store

**Testing**: `terraform fmt -check` and `terraform validate` per workspace; `terraform test` with
mocked providers for wiring checks; Bash test script for the env helpers; JUnit 5 for the
microservice; Python `unittest` (standard library only, so `make check` stays offline and needs no
installed packages) for the notebook's config helper and a notebook-hygiene check; end-to-end validation against a real Confluent Cloud organization via
[quickstart.md](quickstart.md), performed by the project owner (not during implementation)

**Target Platform**: Presenter's macOS/Linux laptop (Terraform CLI, Bash, JDK 21, Maven); managed
services on Confluent Cloud in AWS us-east-2

**Project Type**: Multi-workspace infrastructure-as-code demo with one small application

**Performance Goals**: N/A (demo scale); provisioning time is dominated by Confluent Cloud
(Cluster creation can take several minutes)

**Constraints**: No secrets in git (all `.env` files ignored); each workspace independently
runnable; idempotent re-runs; reverse-order teardown leaves zero resources; Ali's service runs
locally only; all topics Avro

**Scale/Scope**: 5 workspaces, 1 notebook with 1 small helper module, roughly 10 to 20 Terraform resources each (Teresa's has about 1),
3 to 4 topics, 2 to 3 schemas, 2 Flink statements, 1 connector, 1 Tableflow topic, 1 small Java
service

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How the plan satisfies it |
|-----------|--------|---------------------------|
| I. Infrastructure as Code | Pass | Every Confluent Cloud resource is Terraform inside its owning persona directory; nothing is created through the console. |
| II. Secrets Never in Version Control | Pass | `.gitignore` covers every `.env`, state files, `.terraform/`, and the notebook's virtualenv and checkpoints; only `.env.example` (placeholders) is tracked; credentials move Terraform to `.env` by script, never printed. The notebook holds no credentials, is committed with outputs cleared, and an offline hygiene check in `make check` fails on any saved output or secret-looking string (FR-027). |
| III. Reproducible, Resettable Demo | Pass with wording note | Local state per workspace, `prevent_destroy = false`, documented apply and reverse destroy order; destroy also removes the persona's keys from `.env`. See Complexity Tracking for the apply-order wording. |
| IV. Least-Privilege Service Accounts | Pass | One service account per persona with only the role bindings scoped to its topic prefix or resource (see data-model.md). Teresa's is limited to `ResourceOwner` on the single topic `curated-orders` plus `DeveloperRead` on schema subjects (research item 14). Items to verify during implementation are listed in research.md. |
| V. Clarity Over Abstraction | Pass | Flat `.tf` files per persona, no custom modules; two small shared shell scripts are the only cross-cutting code. |
| VI. Personas Communicate Only Through the Environment File | Pass | Workspaces read only `TF_VAR_*` derived from `.env`, never remote state or lookups; the loader fails early naming missing keys. Teresa reads `OMAR_TERESA_*` and `DAN_CURATED_TOPICS`, publishes `TERESA_*`. Her topic-exists check is a data source on the Kafka cluster using her own key, not a lookup of Dan's state. Her notebook reads only keys already in `.env` (`OMAR_ORGANIZATION_ID`, `OMAR_ENVIRONMENT_ID`, `OMAR_KAFKA_CLUSTER_ID`, `OMAR_CLOUD_REGION`, `OMAR_TERESA_TABLEFLOW_API_*`) and publishes nothing, so the contract gains no new required keys. |

Constitution v2.1.0 (Teresa amendment) is the baseline for this re-plan. Post-design re-check
(after Phase 1): all gates still pass; the contract in
[contracts/env-file-contract.md](contracts/env-file-contract.md) defines the only hand-off
interface.

## Project Structure

### Documentation (this feature)

```text
specs/001-persona-terraform-demo/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── env-file-contract.md
└── tasks.md             # created later by /speckit-tasks
```

### Source Code (repository root)

```text
.env.example                      # tracked; placeholder keys only
Makefile                          # per-persona targets (see "Make Targets" below)
.gitignore                        # adds .env, *.tfstate*, .terraform/, target/
scripts/
├── load-env.sh                   # sourced: exports TF_VAR_*, checks required keys
├── publish-env.sh                # upserts terraform outputs into .env
├── unpublish-env.sh              # removes a persona's keys from .env on destroy
└── test-env-scripts.sh           # Bash tests for the three helpers
omar-the-operator/
├── main.tf  variables.tf  outputs.tf
├── environment.tf  kafka.tf  flink.tf  persona-access.tf   # persona-access.tf gains Teresa's service account, bindings, and keys
└── README.md
ida-the-integrator/
├── main.tf  variables.tf  outputs.tf  topics.tf  connector.tf
├── required-env.txt
└── README.md
dan-the-data-guy/
├── main.tf  variables.tf  outputs.tf  schemas.tf  flink.tf
├── schemas/*.avsc
├── flink-sql/*.sql
├── required-env.txt
└── README.md
ali-the-app-developer/
├── main.tf  variables.tf  outputs.tf  topics.tf
├── required-env.txt
├── service/                      # standalone Maven project: downloads Dan's schema, generates classes, runs the producer
│   ├── pom.xml
│   └── src/{main,test}/java/...
└── README.md
```

teresa-from-the-data-team/        # new (User Story 5)
├── main.tf                       # provider "confluent" with Teresa's Tableflow key and Kafka REST settings
├── variables.tf  outputs.tf
├── tableflow.tf                  # topic-exists data source + confluent_tableflow_topic (Iceberg, managed storage)
├── outputs.tftest.hcl            # mocked-provider wiring checks
├── required-env.txt
├── README.md
└── notebook/                     # read-only demo consumer (FR-023 to FR-028); no Terraform, no new keys
    ├── curated_orders.ipynb      # committed with outputs cleared
    ├── catalog_config.py         # stdlib-only: env values to PyIceberg REST settings, early failure, friendly empty-table text
    ├── requirements.txt          # pyiceberg[pyarrow], pandas, matplotlib, jupyterlab (minimum versions)
    ├── test_catalog_config.py    # unittest with fake env values, no network
    └── check_notebook.py         # stdlib-only hygiene check: valid notebook JSON, no outputs, no secret-looking strings

Removed by this feature: `cc-terraform-base/`, `docker-compose.yml`, `scripts/init-vault.sh`
(Vault is no longer used per constitution v2.0.0).

**Structure Decision**: One flat directory per persona (five now) at the repository root, each a standalone
Terraform root module with its own local state. The only shared code is three Bash helpers in
`scripts/` that implement the env-file contract. Ali's Java service lives under his directory as
a standalone Maven project (no root `pom.xml`); `make` targets call it with `mvn -f`.

## Make Targets

A single root `Makefile` (bash shell, explicit targets, no clever pattern rules) wraps the
documented commands so the demo reads as one command per step. Each live target loads `.env`
(for downstream personas), runs Terraform in that persona's directory, and publishes or
unpublishes that persona's keys. Targets print which persona and action they run before
starting.

| Target | What it does |
|--------|--------------|
| `make help` | Lists every target with a one-line description (default target) |
| `make check` | Offline only (the notebook's `unittest` and hygiene check run on the standard library, no installs): `terraform fmt -check`, `init -backend=false`, `validate`, `test` in all five workspaces, Bash env tests, Maven tests |
| `make env-keys` | Prints the key names present in `.env` grouped by persona prefix, never values |
| `make omar-plan` / `omar-apply` / `omar-destroy` | Omar's workspace; apply publishes `OMAR_*`, destroy unpublishes them |
| `make ida-plan` / `ida-apply` / `ida-destroy` | Ida's workspace; checks required keys first; publishes or unpublishes `IDA_*` |
| `make ali-plan` / `ali-apply` / `ali-destroy` | Ali's workspace; publishes or unpublishes `ALI_*` |
| `make ali-run` | Runs Ali's local microservice using values from `.env` |
| `make dan-plan` / `dan-apply` / `dan-destroy` | Dan's workspace; publishes or unpublishes `DAN_*` |
| `make teresa-notebook` | Creates `teresa-from-the-data-team/notebook/.venv` on first use and installs `requirements.txt`, loads `.env`, and launches JupyterLab on the notebook; read-only, never run by `check` |
| `make teresa-plan` / `teresa-apply` / `teresa-destroy` | Teresa's workspace; checks required keys (including `DAN_CURATED_TOPICS`) first; publishes or unpublishes `TERESA_*` |
| `make demo-up` | Applies Omar, Ida, Ali, Dan, then Teresa in order (stops at the first failure) |
| `make demo-down` | Destroys Teresa, Dan, Ali, Ida, then Omar in reverse order |

`PERSONAS` in the Makefile and the `env-keys` prefix list also gain Teresa (`teresa-from-the-data-team`,
`TERESA`). `demo-up` and `demo-down` do not start or stop Ali's microservice; `ali-run` is a separate,
foreground step so the audience sees events being produced. `apply` and `destroy` targets run
Terraform with `-auto-approve`, so no target stops to ask for confirmation; nothing is created or removed
unattended.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Constitution III names the apply order "Omar, then Ida, Dan, and Ali"; the plan applies Omar, Ida, Ali, then Dan, and runs Ali's microservice last | Dan's Flink SQL and schemas need the topics Ida and Ali create, and Ali's producer must use schemas Dan registers, so the real dependency is Omar to {Ida, Ali} to Dan to Ali's service | Applying Dan before Ali would make Dan reference topics that do not exist yet; the intent of Principle III (documented dependency order, reverse teardown) is met. Resolved: the constitution was PATCH-amended (v2.0.1) to say "dependency order as documented in the quickstart". |
| Teresa's apply must follow Dan's, and Omar's Teresa bindings name `curated-orders` exactly rather than a `curated-*` prefix | `ResourceOwner` on the exact topic gives Teresa the smallest scope that can enable Tableflow, matching SC-009; Dan's topic name is a variable default (`curated-orders`) | A `curated-*` prefix binding would let Teresa enable Tableflow on every curated topic Dan ever adds, which is broader than the spec allows. If Dan renames the topic, Omar's binding must change with it (recorded in Omar's README). |

## Teresa's Notebook (FR-023 to FR-028)

- **Config helper** (`catalog_config.py`): reads the environment (loaded from `.env` by
  `make teresa-notebook`, as `make ali-run` does), and returns PyIceberg REST settings: the catalog
  `uri` derived from the organization, environment, and region values (or an override), the
  `credential` as `<key>:<secret>` from Teresa's Tableflow key, an optional `warehouse`, and the access
  delegation header; the namespace is the cluster ID and the table is `curated-orders`. It raises one
  error naming every missing value (FR-026), never prints a secret, and turns "no such table" or
  "no rows" into a plain message.
- **Notebook** (`curated_orders.ipynb`): a few cells that import the helper, open the catalog, scan the
  table into pandas, chart orders by state (and a recent-orders table), and print the friendly message
  for an empty or missing table.
- **Offline checks**: `python3 -m unittest` for the helper with fake values; `check_notebook.py`
  verifies the notebook is valid, has no outputs or execution counts, and contains no key, secret,
  or `lkc-`/`env-`/org-ID-looking string; both are wired into `make check`.
- **Overrides** (optional, hand-set in the shell or `.env`, never published by any persona):
  `TABLEFLOW_CATALOG_ENDPOINT` and `TABLEFLOW_CATALOG_WAREHOUSE`. They exist because the URL form and
  warehouse value are unconfirmed (research items 18 and 19).
