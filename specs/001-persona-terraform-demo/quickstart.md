# Quickstart: Persona-Based Confluent Cloud Terraform Demo

End-to-end validation guide, run by the project owner. Implementation never runs the live steps; only `make check` (offline) is run while building. Details of keys are in
[contracts/env-file-contract.md](contracts/env-file-contract.md); entities are in
[data-model.md](data-model.md).

## Prerequisites

- Terraform >= 1.7, Bash, `jq`, `make`, JDK 21, Maven 3.9+
- A Confluent Cloud organization with quota for a Standard cluster, Advanced governance, and a
  Flink compute pool in AWS us-east-2
- Organization-level credentials exported in your shell (never in the repo):
  `export CONFLUENT_CLOUD_API_KEY=...` and `export CONFLUENT_CLOUD_API_SECRET=...`
- Your organization's UUID for Omar: `export TF_VAR_organization_id=...` (Omar's only input
  that is not a default; it is published to `.env` as `OMAR_ORGANIZATION_ID`)
- `.env` created from `.env.example` (it starts with no persona values)

Tableflow (Teresa) needs Tableflow available in your organization and region; the demo's
AWS `us-east-2` is supported (research item 16). No storage bucket is needed.

## 0. See what is available

```bash
make help
```

## 1. Offline checks (no cloud resources)

```bash
make check
```
Expected: formatting, validation, mocked `terraform test`, env-helper tests, and Maven tests all pass.

## 2. Apply in dependency order

One command per persona (each runs with `-auto-approve`; each loads `.env`,
applies, and publishes that persona's keys):

```bash
make omar-apply
make ida-apply
make ali-apply
make dan-apply
make teresa-apply
# or all five, in order:
make demo-up
```

Use `make <persona>-plan` to preview any step and `make env-keys` to see which keys are in `.env`
(names only).

Expected outcomes:
- Omar: environment (Advanced governance), Standard cluster, and Flink pool visible in
  us-east-2; `.env` now contains `OMAR_*` keys (SC-001, FR-006).
- Ida: topic `landing-orders` exists; the Datagen connector is running; generated order records
  arrive continuously as Avro.
- Ali: application topic `app-events` exists; credentials limited to `app-*`.
- Dan: Avro schemas registered; Flink statements running on Omar's pool.
- Teresa: Tableflow is enabled on `curated-orders` (Iceberg, Confluent-managed storage) and
  `.env` contains `TERESA_TABLEFLOW_TOPIC` and `TERESA_TABLE_FORMATS`. Once records flow (step 3),
  the table appears as syncing and then holds order data (SC-008). It can take a few minutes for a
  low-throughput topic.
- `git status` shows no `.env` (SC-002).

## 3. Run Ali's microservice

```bash
make ali-run
```
Expected: events appear on the application topic; Dan's output topics receive transformed records
(SC-004). Stop it with Ctrl-C before teardown.

## 3a. Show Teresa's table in the notebook

```bash
make teresa-notebook
```
Expected: a JupyterLab window opens on `curated_orders.ipynb` (the first run builds a local
virtualenv). Run all cells: a chart of orders by state and a table of recent orders appear
(SC-010). If the table has not materialized yet, the notebook says so; wait a few minutes and run
again (SC-011). Confirm nothing leaked: `make check` runs the notebook hygiene check, and
`git status` shows no saved outputs. Endpoint overrides, if the derived URL is wrong:
`TABLEFLOW_CATALOG_ENDPOINT` and `TABLEFLOW_CATALOG_WAREHOUSE` (research items 18 and 19).

## 4. Idempotency and failure checks

- Re-run `make <persona>-apply` for any persona: expect "No changes" (SC-006).
- Remove `OMAR_IDA_KAFKA_API_KEY` from `.env`, run `make ida-plan`: expect a failure naming that
  key before Terraform runs (FR-009). Restore the key.
- Using Ali's credentials, attempt to produce to a `landing-*` topic: expect authorization failure.
- Apply an incompatible schema change in Dan's workspace: expect rejection.
- Remove `DAN_CURATED_TOPICS` from `.env`, run `make teresa-plan`: expect a failure naming that key
  before Terraform runs (FR-020, FR-022). Restore the key.
- Using Teresa's Kafka key, attempt to read or manage any topic other than `curated-orders`:
  expect an authorization failure (SC-009).

## 5. Teardown in reverse order

```bash
# stop the microservice first (Ctrl-C)
make teresa-destroy
make dan-destroy
make ali-destroy
make ida-destroy
make omar-destroy
# or all five, in reverse order:
make demo-down
```
Expected: no demo resources remain in the organization (SC-005) and `.env` has no persona keys.
