# Ida the Integrator

Ida brings data into Kafka. This workspace creates one landing topic and one managed
[Datagen Source](https://docs.confluent.io/cloud/current/connectors/cc-datagen-source.html)
connector that generates sample **orders** and writes them as **Avro** records. There is no
external API or API key.

| Topic | Connector | Quickstart | Record interval |
|-------|-----------|------------|-----------------|
| `landing-orders` | `orders-datagen-source` | `ORDERS` | 1 second (`orders_interval_ms`, default 1000) |

Topic names use hyphens only (no dots) and start with `landing-`, the prefix Omar scoped Ida's
access to.

## Prerequisites

- Omar has been applied (`make omar-apply`), so `.env` holds the `OMAR_*` keys Ida needs (listed in
  `required-env.txt`; loading fails early and names any that are missing)
- Terraform 1.7 or newer, `jq`

## Run

From the repository root:

```bash
make ida-plan
make ida-apply      # creates the topic and connector, then publishes the IDA_* keys to .env
```

Published keys: `IDA_ORDERS_TOPIC`, `IDA_ORDERS_CONNECTOR_NAME`.

## Tear down

```bash
make ida-destroy    # removes the connector and topic, and the IDA_* keys from .env
```

## Schemas

The connector registers the Avro schema for the orders it generates (`landing-orders-value`). Dan
reads that schema and does not register his own for `landing-*` topics.

## Things to confirm on the first live apply

These follow Confluent's Datagen Source connector documentation but have not run against
Confluent Cloud yet:

- **Property names** (`kafka.topic`, `quickstart`, `output.data.format`, `max.interval`) in
  `connector.tf`. If the connector rejects a name, check the connector's configuration reference
  and adjust.
- **Schema Registry access.** The connector registers its schema as Ida's service account, which
  Omar grants `DeveloperWrite` on `landing-*` subjects. If the connector fails on schema
  registration, check that binding (and whether the connector needs Schema Registry credentials).
- **Role.** Ida's service account holds `CloudClusterAdmin` on the cluster, the broad role known
  to allow connector management. Replace it with a narrower role if you confirm one (see Omar's
  README).
