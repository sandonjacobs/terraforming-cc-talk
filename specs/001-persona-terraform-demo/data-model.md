# Data Model: Persona-Based Confluent Cloud Terraform Demo

## Entities

### Persona
| Field | Description |
|-------|-------------|
| name | Operator, Integrator, Data Guy, App Developer, Data Team Analyst (Teresa) |
| workspace | Directory: `omar-the-operator`, `ida-the-integrator`, `dan-the-data-guy`, `ali-the-app-developer`, `teresa-from-the-data-team` |
| key prefix | `OMAR_`, `IDA_`, `DAN_`, `ALI_`, `TERESA_` for values it publishes |
| required keys | Keys it must find in `.env` (listed in its `required-env.txt`; Omar has none) |

Relationships: Omar has no upstream. Ida and Ali depend on Omar. Dan depends on Omar, Ida, and
Ali. Teresa depends on Omar (her credentials) and Dan (the `curated-orders` topic). Ali's microservice
additionally depends on Dan's schemas.

### Shared Environment File (`.env`)
Plain `KEY=value` lines at the repository root, gitignored. Constraints:
- Keys are unique; each key is owned by exactly one persona (its prefix).
- Publishing upserts only that persona's keys; unpublishing removes only that persona's keys.
- Contents are never printed by the helper scripts.

### Platform Foundation (Omar)
Environment (Advanced governance), Standard Kafka cluster, Schema Registry, Flink compute pool,
all in AWS us-east-2. Identified by `OMAR_*` platform keys.

### Persona Credentials (Omar creates, one set per downstream persona)
Service account, role bindings, and API keys scoped as below.

| Persona | Kafka key | Schema Registry key | Flink key | Cloud key | Access scope |
|---------|-----------|---------------------|-----------|-----------|--------------|
| Ida | yes | write `landing-*` subjects (to confirm, research item 8) | no | yes (connector management) | write/manage `landing-*` |
| Ali | yes | yes (read subjects) | no | no | write/manage `app-*` |
| Dan | yes | yes (write subjects) | yes | no | read `landing-*`, `app-*`; read/write/manage `curated-*`; Flink developer |
| Teresa | yes (cluster-scoped; used by the Tableflow resource) | no key; role only (`DeveloperRead` on all subjects) | no | no; a Tableflow-scoped key instead | `ResourceOwner` on topic `curated-orders` only |

### Connector and Landing Topic (Ida)
One topic, `landing-orders` (Avro value), fed by a Datagen Source connector using the Orders
quickstart at a configurable record interval. Connector states: provisioning, running, failed.

### Application Topic and Microservice (Ali)
Topic `app-<name>` (Avro value) and a local producer that sends schema-conforming events using
Ali's credentials. The producer never registers schemas.

### Schema and Flink Statement (Dan)
- Schema: Avro definition registered under subject `<topic>-value` for the topics Dan and Ali
  own (`app-events`, `curated-*`); the `landing-orders` schema is registered by Ida's
  connector and read by Dan (see research.md item 9).
- Flink statement: named SQL statement running on Omar's compute pool, writing to a
  `curated-<name>` topic. States follow Confluent's statement lifecycle (pending, running,
  completed, failed).

### Tableflow Iceberg Table (Teresa)
Tableflow enablement on topic `curated-orders` with `table_formats = ["ICEBERG"]` and
Confluent-managed storage (no bucket, no provider integration). Published as
`TERESA_TABLEFLOW_TOPIC` and `TERESA_TABLE_FORMATS`. States: not enabled, syncing (materializing,
best-effort a few minutes for low-throughput topics), suspended, failed. The table is empty until
records reach `curated-orders`.

## Validation rules (from requirements)

- A downstream workspace MUST stop before planning if any required key is missing (FR-009).
- All topics MUST have Avro value schemas (FR-011).
- Re-running a workspace with unchanged inputs MUST yield zero changes (FR-015).
- Teresa's workspace MUST stop before planning if `DAN_CURATED_TOPICS` or any `OMAR_TERESA_*` key
  is missing, and MUST fail if `curated-orders` is not in the cluster (FR-020, FR-022).
- Teresa's credentials MUST NOT carry a role on any topic other than `curated-orders` (FR-018,
  SC-009), and Dan's workspace MUST NOT declare a Tableflow resource (FR-021).
- Destroying a workspace MUST remove that persona's keys from `.env` (supports FR-016 and the
  stale-value edge case).

## State transitions

```text
fresh -> omar applied -> ida applied -> ali applied -> dan applied -> teresa applied -> ali service running
ali service stopped -> teresa destroyed -> dan destroyed -> ali destroyed -> ida destroyed -> omar destroyed -> fresh
```

## Demo Notebook (Teresa)

Read-only consumer of the Tableflow table; not a provisioned resource.

| Field | Description |
|-------|-------------|
| inputs | From `.env` only: `OMAR_ORGANIZATION_ID`, `OMAR_ENVIRONMENT_ID`, `OMAR_KAFKA_CLUSTER_ID`, `OMAR_CLOUD_REGION`, `OMAR_TERESA_TABLEFLOW_API_KEY`, `OMAR_TERESA_TABLEFLOW_API_SECRET`; optional overrides `TABLEFLOW_CATALOG_ENDPOINT`, `TABLEFLOW_CATALOG_WAREHOUSE` |
| reads | Table `<cluster-id>.curated-orders` through the Tableflow REST catalog |
| shows | A chart of orders by state and a table of recent orders |
| publishes | Nothing (adds no `.env` keys) |

Validation rules: stops before connecting if any required input is missing, naming all of them
(FR-026); shows a plain message for an empty or missing table (FR-026); the committed notebook has
no outputs and no secret-looking strings (FR-027).
