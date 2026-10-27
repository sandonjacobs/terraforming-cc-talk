# Teresa from the data team

Teresa wants the `curated-orders` data as an Iceberg table for reporting. This workspace enables
Tableflow on that one topic, with Iceberg as the table format and Confluent-managed storage, so no
bucket, IAM role, or provider integration is needed.

| Enables Tableflow on | Format | Storage |
|----------------------|--------|---------|
| `curated-orders` (Dan's Flink output) | Iceberg | Confluent-managed |

Teresa owns the Tableflow resource; Dan's workspace does not manage it. Her service account (issued
by Omar) can enable and read Tableflow on `curated-orders` only, plus read schemas.

## Prerequisites

- Omar, Ida, Ali, and Dan have been applied, so `curated-orders` exists and `.env` holds the keys
  listed in `required-env.txt` (loading fails early and names any that are missing)
- Terraform 1.7 or newer, `jq`

## Run

From the repository root:

```bash
make teresa-plan
make teresa-apply   # enables Tableflow on curated-orders, then publishes TERESA_* keys
```

Published keys: `TERESA_TABLEFLOW_TOPIC` and `TERESA_TABLE_FORMATS`.

The table shows as syncing and stays empty until records reach `curated-orders`. For a
low-throughput topic, materialization is best-effort and takes a few minutes.

## Notebook

`notebook/curated_orders.ipynb` shows the table for the talk: a chart of orders by state and the ten
most recent orders. It reads the Iceberg table through the Tableflow REST catalog with PyIceberg, uses
Teresa's own Tableflow key, and is read-only (it creates nothing in Confluent Cloud).

```bash
make teresa-notebook   # builds notebook/.venv on first run, then opens JupyterLab
```

- **Setup.** The first run installs `notebook/requirements.txt` into `notebook/.venv`, which needs
  network access once. Python 3.11 to 3.13 is recommended; choose one with
  `PYTHON=python3.12 make teresa-notebook`; by default the first of `python3.13`, `python3.12`,
  `python3.11` on your machine is used. Later runs skip the install unless `requirements.txt` changes. The tests and checks in `make check` need no installs.
- **Configuration.** Everything comes from `.env`: the organization, environment, cluster, and region
  values, and Teresa's Tableflow key and secret. Only those keys are exported to the notebook, never
  other personas' secrets. If any is missing, the target stops and names all of
  them before Jupyter starts. Nothing is typed in by hand.
- **Overrides.** If the derived catalog URL or the warehouse is wrong for your setup, set
  `TABLEFLOW_CATALOG_ENDPOINT` (the REST catalog URL from the Tableflow overview page) and
  `TABLEFLOW_CATALOG_WAREHOUSE` (the warehouse, left unset by default) in your shell or `.env`.
- **Empty table.** Right after `make teresa-apply`, or before records reach `curated-orders`, the
  notebook prints that the table is empty or not available yet. Wait a few minutes and run the cell
  again.
- **Before you commit.** Clear all outputs (Edit, Clear Outputs of All Cells). `make check` runs
  `notebook/check_notebook.py`, which fails on saved outputs, execution counts, or anything that
  looks like a key or Confluent ID.

Not yet confirmed against a live organization (research.md items 18 to 21): the exact catalog URL
form, the warehouse, the namespace (the cluster ID), whether the topic-scoped `ResourceOwner`
role is enough to read through the catalog, and library wheels on Python 3.14.

## Tear down

```bash
make teresa-destroy   # disables Tableflow and removes TERESA_* keys from .env
```

Do this before destroying Dan: `make dan-destroy` refuses to run while `TERESA_*` keys are still
in `.env`.

## How the topic check can fail

The workspace checks twice that `curated-orders` is there, and each failure reads differently:

- **`DAN_CURATED_TOPICS` is missing or does not list the topic.** `make teresa-plan` stops before
  Terraform runs (a missing key), or Terraform fails with "curated-orders is not in
  DAN_CURATED_TOPICS: apply Dan's workspace first". Fix: run `make dan-apply`.
- **The key is listed but the topic is not in the cluster** (Dan was destroyed by hand and `.env`
  is stale). The topic lookup fails with the Kafka REST error. If it reads as an authorization
  error rather than "not found", the cause is Teresa's role binding (see below), not Dan.

## Things to confirm on the first live apply

- **Tableflow API key.** Omar creates it with `managed_resource` set to id `tableflow`, api_version
  `tableflow/v1`, kind `Tableflow`. Confirm against the provider docs (research.md item 14a).
- **Role binding before the topic exists.** Omar's `ResourceOwner` binding on `curated-orders`
  is created before Dan creates the topic. If it is rejected, apply it after Dan; do not widen it to
  `curated-*` (research.md item 14b).
- **`managed_storage {}`.** The empty block selects Confluent-managed storage. Confirm whether it
  may be omitted (research.md item 15).
- **Schema from a Flink statement.** The `curated-orders` schema is registered by Dan's Flink
  statement, not by Terraform. Confirm Tableflow accepts it and that an empty topic enables
  cleanly (research.md item 17).
- **Entitlement.** Tableflow must be available to your organization; `us-east-2` is supported.
