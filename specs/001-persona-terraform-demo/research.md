# Research: Persona-Based Confluent Cloud Terraform Demo

Decisions made from the spec, the constitution (v2.0.0), and the existing Terraform in
`cc-terraform-base/`. Items marked **Verify** rest on knowledge of the Confluent provider and
Confluent Cloud that must be confirmed against current provider docs during implementation;
none block the design.

## 1. Moving values between `.env` and Terraform

- **Decision**: A sourced Bash helper (`scripts/load-env.sh`) reads the root `.env`, exports each
  `KEY=value` as `TF_VAR_<key lowercased>`, and fails with a message naming any key listed in the
  persona's `required-env.txt` that is missing. After `terraform apply`, `scripts/publish-env.sh`
  reads `terraform output -json` and upserts each output into `.env` under that persona's keys.
  `scripts/unpublish-env.sh` removes them on destroy.
- **Rationale**: Terraform cannot read `.env` files natively, and it silently ignores undeclared
  `TF_VAR_*` variables, so exporting everything is safe. Upserting line by line (never rewriting
  the whole file) satisfies "do not overwrite other personas' values" (FR-008a). Early failure
  satisfies FR-009.
- **Alternatives considered**: Terraform `local_file` writing the whole `.env` (overwrites other
  personas' keys); per-persona `.tfvars` files (violates the single-file clarification); Terraform
  `terraform_remote_state` (violates Principle VI); a third-party dotenv provider (extra
  dependency, harder to explain on stage).

## 2. Key naming

- **Decision**: Keys are `UPPER_SNAKE_CASE` prefixed by the publishing persona
  (`OMAR_`, `IDA_`, `DAN_`, `ALI_`). Omar's credentials for each downstream persona include that
  persona in the name (for example `OMAR_IDA_KAFKA_API_KEY`). Full list in
  [contracts/env-file-contract.md](contracts/env-file-contract.md).
- **Rationale**: The prefix makes ownership obvious to an audience and makes unpublish a simple
  prefix match.
- **Alternatives considered**: Unprefixed keys (collision risk); nested files or JSON (not `.env`).

## 3. Terraform state

- **Decision**: Default local backend in each persona directory; state files gitignored.
- **Rationale**: Principle III requires local, per-workspace state. The existing `workspace_dir`
  path under `~/.terraform-state/` was non-standard and unnecessary.
- **Alternatives considered**: Keeping the home-directory path (hides state from the demo, harder
  to reset); remote state (explicitly excluded).

## 4. Provider authentication per persona

- **Decision**: Omar runs with organization-level credentials supplied by the presenter as
  `CONFLUENT_CLOUD_API_KEY` and `CONFLUENT_CLOUD_API_SECRET` exported in the shell (outside the
  repo). Every other persona configures the provider with the resource-scoped values Omar
  published: Kafka REST endpoint plus Kafka API key (topics), Schema Registry endpoint plus key
  (schemas), Flink endpoint plus key with organization, environment, pool, and principal IDs
  (statements).
- **Rationale**: The provider supports resource-scoped configuration, so downstream personas
  never need organization-level credentials, which supports least privilege.
- **Verify**: Managed connector management (`confluent_connector`) is a control-plane operation
  that normally authenticates with a Cloud API key rather than a cluster key. Plan: Omar creates a
  Cloud API key for Ida's service account with the narrowest role that permits managing connectors
  in the environment. If no narrower role exists, fall back to an environment-scoped role and
  document it as a deliberate trade-off in Ida's README.

## 5. Omar's platform resources

- **Decision**: `confluent_environment` with `stream_governance { package = "ADVANCED" }`;
  `confluent_kafka_cluster` with a `standard {}` block in AWS us-east-1;
  `confluent_flink_compute_pool` in the same environment and region with a small `max_cfu`;
  Schema Registry looked up through the existing data source pattern.
- **Rationale**: Directly matches FR-002 to FR-004 and the pattern already used in `kafka.tf`.
- **Decision (revised after live run)**: Standard, not Enterprise. Enterprise clusters require a
  PrivateLink access point (the console reports "Cluster networking setup incomplete" without one),
  which a laptop-run Terraform, managed connectors, Flink and Ali's local producer cannot use. Standard
  is public with no networking resources. Availability is `SINGLE_ZONE` to keep the demo cheap.

## 6. Per-persona service accounts and role bindings

- **Decision**: Omar creates one service account per downstream persona and scopes role bindings
  by topic prefix:
  - Ida: write and manage on topics `landing-*`; connector management as in item 4.
  - Ali: write and manage on topics `app-*`; read on the matching Schema Registry subjects.
  - Dan: read on `landing-*` and `app-*`; read/write/manage on `curated-*`; Schema Registry
    subject write; Flink developer on the environment; the assigner role on his own service
    account so his statements can run under it.
- **Rationale**: Principle IV and FR-005; topic prefixes make ownership visible and let access
  denial outside scope be demonstrated (Ali acceptance scenario 3).
- **Verify**: Exact role names and CRN patterns for prefixed topic and subject bindings, and the
  minimum Flink roles for statement execution.
- **Alternatives considered**: One shared admin account (violates Principle IV); creating topic
  ACLs instead of RBAC (less consistent with the existing role-binding approach).

## 7. Topic naming and dependency order

- **Decision**: Ida's topic `landing-orders`, Ali's
  `app-events`, Dan's outputs `curated-<name>`.
  Apply order is Omar, Ida, Ali, Dan, then run Ali's microservice; teardown is the reverse
  (stop microservice, Dan, Ali, Ida, Omar).
- **Rationale**: Dan's schemas and SQL need topic names from Ida and Ali, and Ali's producer must
  serialize with schemas Dan registers (Avro, auto-registration disabled so Dan's contracts win).
  This is a refinement of the order in the spec's assumptions and constitution Principle III;
  recorded in the plan's Complexity Tracking.
- **Alternatives considered**: Ali's service auto-registering its own schema (undercuts Dan's
  role); Dan before Ali (references topics that do not exist).

## 8. Ida's Datagen connector

- **Decision**: One `confluent_connector` resource using the managed Datagen Source connector
  (`DatagenSource`) with `quickstart = ORDERS`, output format Avro, topic `landing-orders`, one
  task, and a record interval (`max.interval`, milliseconds) exposed as a variable with a slow
  default (1000 ms). The connector authenticates with Ida's Kafka API key.
- **Rationale**: Removes the external API, its key, endpoint and schema-inference questions (the
  earlier BART HTTP Source design). Orders have a stable, well-known Avro shape, so Dan's SQL can
  be written against it with confidence. It still shows Ida's persona: a managed connector plus a
  landing topic, with no hosting.
- **Supersedes**: The earlier decision of two HTTP Source connectors against the BART API.
- **Verify**: (a) property names for the connector (`kafka.topic`, `quickstart`,
  `output.data.format`, `max.interval`, `tasks.max`) against the current Datagen Source docs;
  (b) the connector registers `landing-orders-value` in Schema Registry, which needs write access
  for Ida's service account on `landing-*` subjects (Omar's `persona-access.tf` currently gives
  Ida no Schema Registry binding, so this likely needs a new binding and the connector may need
  Schema Registry credentials); (c) whether `CloudClusterAdmin` is still needed now that only one
  connector is managed.
- **Alternatives considered**: Keeping BART (external dependency, key handling, unknown payload
  shape); a custom producer (not managed, contradicts the persona story).

## 8a. Topic naming

- **Decision**: No dots in topic names; hyphens only. Names are `landing-orders`,
  `app-events`, and `curated-*`.
- **Rationale**: Direct user instruction (FR-010a). Hyphen prefixes still work with prefixed role
  bindings (`landing-*`, `app-*`, `curated-*`).
- **Alternatives considered**: Underscores (also valid, but hyphens match the existing naming
  style in the repo).

## 9. Dan's schemas and Flink SQL

- **Decision**: Avro schema files in `dan-the-data-guy/schemas/` registered with
  `confluent_schema` under `<topic>-value` subjects; Flink SQL in `flink-sql/*.sql` deployed with
  `confluent_flink_statement` (one statement that flattens Ida's orders into `curated-orders`). Ali's events
  are registered but not yet transformed; their use case is to be decided. Schemas and SQL are
  illustrative.
- **Schema ownership decision**: The connector registers the Avro schema it generates for the
  landing topic (`landing-orders-value`). Dan registers
  schemas for the topics he and Ali own (`app-events`, `curated-*`) and reads the landing schemas
  from Schema Registry through Flink. Dan pre-registering landing schemas would conflict with the
  connector's own registration. **Verify** the connector's behavior (research item 8b); if the
  connector can use a pre-registered schema, Dan can own all schemas as the spec describes and
  the spec should say so.
- **Rationale**: Keeps files readable on stage and separate from HCL.
- **Verify**: Compatibility mode `BACKWARD` set in the environment's Schema Registry (carried over
  from the current config) rejects incompatible changes (Dan acceptance scenario 3).

## 10. Ali's microservice

- **Decision**: Java 21 Maven module under `ali-the-app-developer/service/`, using the Kafka
  producer with the Confluent Avro serializer, `auto.register.schemas=false` and
  `use.latest.version=true`, generating synthetic events. Configuration is read from environment
  variables derived from `.env` (documented run command). The module is standalone (no root
  `pom.xml`). Its build is schema-first: the `kafka-schema-registry-maven-plugin` `download` goal
  fetches the `<topic>-value` subject Dan registered, using Ali's Schema Registry credentials, then
  `avro-maven-plugin` generates `AppEvent` and `EventType` from it. An `-Doffline` profile copies
  Dan's `app-events.avsc` instead so `make check` needs no Schema Registry.
- **Rationale**: The constitution requires JVM code to use Maven; Java is the most common language
  in Kafka talks. Generating classes from the registered schema makes Dan's contract the single
  source of truth, and a schema change surfaces as a compile error in Ali's code. Ali's existing
  `DeveloperRead` on `subject=app-*` is enough for the download.
- **Alternatives considered**: Python or Go (adds a second toolchain, conflicts with the Maven
  constraint).

## 11. Testing approach

- **Decision**: `terraform fmt -check` and `terraform validate` in every workspace, `terraform
  test` with mocked providers for wiring (for example, outputs match the contract keys), a Bash
  test script for the three env helpers using temporary `.env` files, JUnit tests for the
  producer's event generation, and the quickstart as the end-to-end acceptance run.
- **Rationale**: Real provisioning costs money and time, so most checks run offline; the quickstart
  covers what mocks cannot.

## 12. Repository cleanup

- **Decision**: Delete `cc-terraform-base/`, `docker-compose.yml`, and `scripts/init-vault.sh`;
  migrate environment, cluster, Schema Registry, and service account logic into Omar's workspace;
  delete the root `pom.xml` (the only Maven module is Ali's service, which builds on its own).
- **Rationale**: FR-017 and constitution v2.0.0 remove Vault.

## 13. Per-persona Make targets and implementation boundary

- **Decision**: A root `Makefile` provides `<persona>-plan|apply|destroy`, `ali-run`, `demo-up`,
  `demo-down`, `check`, `env-keys`, and `help`. Implementation produces and validates code offline
  only; no live Confluent Cloud calls.
- **Rationale**: One command per demo step is easier to present and follow than the multi-command
  shell lines, and keeps load/apply/publish ordering in one reviewed place. The project owner
  starts live testing separately, so implementation must not provision anything.
- **Alternatives considered**: Per-persona shell scripts (more files to explain); a task runner
  such as `just` (extra tool to install); long inline commands in the README (error-prone live).

## 14. Teresa's access: roles and API keys for Tableflow

- **Decision**: Omar creates `confluent_service_account.teresa` with two role bindings and two API
  keys.
  - `ResourceOwner` on `${kafka_crn}/topic=curated-orders` (exact topic, not a prefix).
  - `DeveloperRead` on `${sr_crn}/subject=*` (Tableflow reads each topic's schema; the docs
    require read on all subjects).
  - A cluster-scoped Kafka API key, used for the `credentials` block of `confluent_tableflow_topic`
    and the topic-exists data source.
  - A Tableflow API key (`confluent_api_key` with `managed_resource` set to id `tableflow`,
    api_version `tableflow/v1`, kind `Tableflow`), used as the provider's `tableflow_api_key` and
    `tableflow_api_secret`.
- **Rationale**: Confluent's Tableflow RBAC page lists no Tableflow-specific roles. For managed
  storage, enabling Tableflow needs `ResourceOwner` on the topic (or `CloudClusterAdmin`) plus
  `DeveloperRead` on all schema subjects. `Assigner` on provider integrations is only for
  bring-your-own storage, so Teresa does not get it. `ResourceOwner` also covers data-plane
  reads, so no extra read role is needed. This is narrower than `CloudClusterAdmin` and keeps
  Teresa's reach to one topic (SC-009).
- **Verify**: (a) the `managed_resource` values for the Tableflow API key against the provider's
  `confluent_api_key` docs; (b) that a topic-scoped `ResourceOwner` on a topic that does not exist
  yet is accepted when Omar applies; (c) that the Tableflow key's permissions follow the owning
  service account as documented ("same permissions as the principal that created it"), so the
  Iceberg REST catalog is readable with it.
- **Alternatives considered**: `CloudClusterAdmin` (known to work but cluster-wide); a
  `curated-*` prefix binding (broader than FR-018 allows; see Complexity Tracking); one shared Dan
  account (violates Principle IV and FR-021).

## 15. `confluent_tableflow_topic` resource and provider version

- **Decision**: Teresa's workspace uses `confluent_tableflow_topic` with `display_name =
  "curated-orders"`, `table_formats = ["ICEBERG"]`, an empty `managed_storage {}` block,
  `environment { id }`, `kafka_cluster { id }`, and `credentials { key, secret }` set to her Kafka
  API key. The provider block sets `tableflow_api_key` and `tableflow_api_secret`. The existing
  `>= 2.91.0` constraint is kept; the committed lock file already pins 2.91.0, whose schema
  (checked with `terraform providers schema`) contains the resource, the
  `managed_storage`, `byob_aws`, `azure_data_lake_storage_gen_2` and `google_cloud_storage`
  blocks, and the provider-level Tableflow key attributes.
- **Rationale**: Choosing no bring-your-own block with `managed_storage {}` is how the schema
  expresses Confluent-managed storage (FR-019); no provider integration or bucket is declared.
  `retention_ms` is optional (default 7 days); we leave it at the default to stay simple.
- **Verify**: whether `managed_storage {}` must be written explicitly or may be omitted (the
  schema lists it as an optional block with no attributes); validate offline with
  `terraform validate`.
- **Alternatives considered**: Bring-your-own S3 (rejected by the user: managed storage); a Delta
  Lake format (the spec asks for Iceberg).

## 16. Tableflow availability for this cluster and region

- **Decision**: No change to Omar's platform. Tableflow is supported in AWS `us-east-2` and the
  Confluent feature table shows Tableflow available for Basic, Standard, Enterprise, Freight and
  Dedicated clusters, so the existing Standard cluster qualifies.
- **Rationale**: Confluent's "Supported Cloud Regions" page lists `us-east-2` for Tableflow
  and states the cluster-type table is independent of region.
- **Verify**: org-level entitlement or quota for Tableflow (the spec's edge case) can only be
  confirmed by the project owner's first live apply.

## 17. Dan's Flink output and fail-early behavior

- **Decision**: Dan's `CREATE TABLE ... AS SELECT` from `landing-orders` is an append-only
  stream (no joins or aggregations), so Tableflow can materialize it without upsert handling. Teresa's
  workspace fails early in two places: `scripts/load-env.sh` stops if `DAN_CURATED_TOPICS` is
  missing (Dan never applied), and a `data "confluent_kafka_topic"` for `curated-orders`, read
  with her Kafka key, fails the plan if the topic is not in the cluster (stale `.env` after Dan was
  destroyed).
- **Rationale**: Satisfies FR-020 and FR-022 without reading another persona's state (Principle
  VI).
- **Verify**: that Tableflow accepts a topic whose Avro schema was registered by a Flink
  statement (the schema is created by Dan's statement, not by Dan's `confluent_schema`); that an
  empty topic enables cleanly (the table stays empty until Ali and Ida's data arrive); and that
  `curated-orders` in `DAN_CURATED_TOPICS` is matched by exact name (it is a comma-separated list).
- **Alternatives considered**: Only trusting `DAN_CURATED_TOPICS` (cannot detect a stale
  `.env`); a `precondition` on the Tableflow resource alone (fails later and with a less clear
  message).

## 18. Tableflow Iceberg REST catalog endpoint and PyIceberg settings

- **Decision**: The helper builds the `uri` as
  `https://tableflow.<region>.aws.confluent.cloud/iceberg/catalog/organizations/<organization-id>/environments/<environment-id>`
  from `OMAR_CLOUD_REGION`, `OMAR_ORGANIZATION_ID`, and `OMAR_ENVIRONMENT_ID`, and passes it with
  `type = rest`, `credential = "<tableflow key>:<tableflow secret>"`, and the header
  `X-Iceberg-Access-Delegation: vended-credentials`. `TABLEFLOW_CATALOG_ENDPOINT` overrides the
  `uri`; `TABLEFLOW_CATALOG_WAREHOUSE` sets the PyIceberg `warehouse` property (absent by default).
- **Rationale**: Confluent documents a REST catalog endpoint on the Tableflow overview page, and
  PyIceberg's REST catalog takes `uri` and `credential`. The overrides keep the demo working if the
  derived form is wrong, without changing code.
- **Verify** (not confirmed from the Confluent pages I could read): (a) the exact URL form and
  whether `<region>`/`aws` are right for `us-east-2`; (b) the value, if any, for `warehouse` (a likely
  candidate is the Kafka cluster ID) and whether it is required; (c) whether vended credentials are
  needed to read data files from Confluent-managed storage.
- **Alternatives considered**: Copying the endpoint by hand from the console (breaks FR-024's "no
  hand-entered value", kept only as the override); publishing the endpoint from Terraform (the
  `confluent_tableflow_topic` resource does not expose it, and a new key would change the contract).

## 19. Namespace and table naming for a managed-storage table

- **Decision**: Namespace is the Kafka cluster ID (`OMAR_KAFKA_CLUSTER_ID`) and the table name is the
  topic (`curated-orders`), so the table is `<cluster-id>.curated-orders`.
- **Rationale**: Tableflow tables are organized by cluster and topic.
- **Verify**: the namespace form against the console's Tableflow table listing; the helper builds the
  identifier in one place so a fix is one line.

## 20. Can Teresa's Tableflow key read through the catalog?

- **Decision**: Use her existing Tableflow key as the catalog credential; no new roles.
- **Rationale**: Confluent's Tableflow RBAC page gives `ResourceOwner` on the topic data-plane read,
  and an API key carries its owner's permissions.
- **Verify**: that a topic-scoped `ResourceOwner` (not `EnvironmentAdmin`) is enough to list and
  scan the table. If it is not, record the narrowest role that works in Omar's README rather than
  widening to `CloudClusterAdmin` silently (Principle IV).

## 21. Notebook dependencies and offline checks

- **Decision**: `requirements.txt` with minimum versions `pyiceberg[pyarrow]>=0.9`, `pandas>=2.2`,
  `matplotlib>=3.9`, and `jupyterlab>=4.2`; Python 3.11 to 3.13 in a local virtualenv created by
  `make teresa-notebook` (`PYTHON` overridable). The checks use only the standard library: `unittest`
  for the helper and a small `json`-based script for the notebook hygiene check.
- **Rationale**: `make check` is the project's offline gate, so it must not need `pip install` or a
  network. matplotlib keeps the chart code short and works in any notebook; PyArrow is needed for
  `to_pandas()`. Current releases are PyIceberg 0.12, pandas 3.1, matplotlib 3.11, JupyterLab 4.6, so
  the minimums leave room.
- **Verify**: wheel availability for PyArrow and pandas on Python 3.14 (the laptop's default is 3.14.6),
  hence the 3.11 to 3.13 guidance and the `PYTHON` override.
- **Alternatives considered**: pytest and `nbformat` (better messages, but they need installing, so
  `make check` would no longer be offline); Plotly (heavier install for the same chart); Spark
  (needs Docker and a JVM).
