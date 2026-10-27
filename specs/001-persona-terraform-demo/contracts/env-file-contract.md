# Contract: Shared Environment File

The `.env` file at the repository root is the only hand-off interface between personas
(constitution Principle VI). Format: one `KEY=value` per line, no quoting required, no spaces
around `=`, `#` comment lines allowed. The file is gitignored; `.env.example` lists the keys with
placeholder values.

## Helper commands

| Command | Behavior |
|---------|----------|
| `source scripts/load-env.sh <persona-dir>` | Reads `<persona-dir>/required-env.txt` and exports only those keys from `.env` as `TF_VAR_<lowercased key>` (a persona never receives other personas' secrets). Exits non-zero naming every missing or empty key, before Terraform runs. |
| `scripts/publish-env.sh <persona-dir> <PREFIX>` | Reads `terraform output -json` in the persona directory and upserts each output as `<PREFIX>_<OUTPUT_NAME uppercased>`. Leaves all other lines untouched. Never echoes values. |
| `scripts/unpublish-env.sh <PREFIX>` | Removes every `<PREFIX>_*` line from `.env`. |

## Keys published by Omar (`OMAR_`)

Platform values:
`OMAR_ORGANIZATION_ID`, `OMAR_ENVIRONMENT_ID`, `OMAR_ENVIRONMENT_NAME`, `OMAR_CLOUD_REGION`,
`OMAR_KAFKA_CLUSTER_ID`, `OMAR_KAFKA_CLUSTER_NAME`,
`OMAR_KAFKA_BOOTSTRAP_ENDPOINT`, `OMAR_KAFKA_REST_ENDPOINT`, `OMAR_SCHEMA_REGISTRY_ID`,
`OMAR_SCHEMA_REGISTRY_REST_ENDPOINT`, `OMAR_FLINK_COMPUTE_POOL_ID`, `OMAR_FLINK_REST_ENDPOINT`

Per-persona credentials (`<P>` is `IDA`, `ALI`, `DAN`, or `TERESA`):
- `OMAR_<P>_SERVICE_ACCOUNT_ID`
- `OMAR_<P>_KAFKA_API_KEY`, `OMAR_<P>_KAFKA_API_SECRET`
- Ida only: `OMAR_IDA_CLOUD_API_KEY`, `OMAR_IDA_CLOUD_API_SECRET`
- Ali and Dan: `OMAR_<P>_SCHEMA_REGISTRY_API_KEY`, `OMAR_<P>_SCHEMA_REGISTRY_API_SECRET`
- Dan only: `OMAR_DAN_FLINK_API_KEY`, `OMAR_DAN_FLINK_API_SECRET`
- Teresa only: `OMAR_TERESA_TABLEFLOW_API_KEY`, `OMAR_TERESA_TABLEFLOW_API_SECRET` (a Tableflow-scoped
  key). Teresa has no Schema Registry key; her Kafka key is `OMAR_TERESA_KAFKA_API_KEY` and
  `OMAR_TERESA_KAFKA_API_SECRET`.

## Keys published by other personas

| Persona | Keys |
|---------|------|
| Ida (`IDA_`) | `IDA_ORDERS_TOPIC` (landing topic name), `IDA_ORDERS_CONNECTOR_NAME` |
| Ali (`ALI_`) | `ALI_EVENTS_TOPIC` (name of the application topic) |
| Dan (`DAN_`) | `DAN_CURATED_TOPICS` (comma-separated output topic names) |
| Teresa (`TERESA_`) | `TERESA_TABLEFLOW_TOPIC` (topic Tableflow is enabled on), `TERESA_TABLE_FORMATS` (comma-separated, `ICEBERG`) |

## Required keys per workspace

The authoritative list for each workspace is its `required-env.txt`; `load-env.sh` exports exactly
those keys and nothing else.

| Workspace | Needs (summary) |
|-----------|-----------------|
| omar-the-operator | none (uses `CONFLUENT_CLOUD_API_KEY` and `CONFLUENT_CLOUD_API_SECRET` from the shell) |
| ida-the-integrator | environment ID, Kafka cluster ID and REST endpoint, `OMAR_IDA_*` Kafka and Cloud keys (nothing extra from the shell) |
| ali-the-app-developer | Kafka cluster ID and REST endpoint, `OMAR_ALI_KAFKA_API_*` |
| dan-the-data-guy | organization, environment ID and name, Kafka cluster name, Schema Registry ID and endpoint, Flink pool ID and endpoint, `OMAR_DAN_*` service account, Schema Registry, and Flink keys, `IDA_ORDERS_TOPIC`, `ALI_EVENTS_TOPIC` |
| teresa-from-the-data-team | environment ID, Kafka cluster ID and REST endpoint, `OMAR_TERESA_*` Kafka and Tableflow keys, `DAN_CURATED_TOPICS` (so the workspace stops early if Dan has not applied) |
| Teresa's notebook (runtime) | `OMAR_ORGANIZATION_ID`, `OMAR_ENVIRONMENT_ID`, `OMAR_KAFKA_CLUSTER_ID`, `OMAR_CLOUD_REGION`, `OMAR_TERESA_TABLEFLOW_API_KEY`, `OMAR_TERESA_TABLEFLOW_API_SECRET`, plus the optional overrides below; `make teresa-notebook` exports only these, never the whole `.env` |
| Ali's microservice (runtime) | Kafka bootstrap endpoint, Schema Registry endpoint, `OMAR_ALI_*` Kafka and Schema Registry keys, `ALI_EVENTS_TOPIC` (read straight from the environment by `make ali-run`) |

## Guarantees

- Keys are owned by one persona; only that persona's scripts add, change, or remove them.
- Re-publishing with unchanged outputs leaves the file byte-identical.
- No helper prints a secret value to the terminal or logs.

## Optional overrides (not part of the hand-off)

Teresa's notebook reads only keys listed above. Two optional, hand-set variables can override what it
derives; they are not published by any persona and are never required:
`TABLEFLOW_CATALOG_ENDPOINT` (the Iceberg REST catalog URL) and `TABLEFLOW_CATALOG_WAREHOUSE` (the
warehouse). Put them in the shell or in `.env`; `make teresa-notebook` passes `.env` through.
