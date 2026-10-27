# Dan the Data Guy

Dan owns the data contracts and the streaming transformations. This workspace registers the Avro
schema for Ali's events and deploys one Flink SQL statement on Omar's compute pool, running as
Dan's own service account.

| Statement | Reads | Writes (created by the statement, Avro) |
|-----------|-------|------------------------------------------|
| `curate-orders` | `landing-orders` | `curated-orders` (orders with the address flattened into `city`, `state`, `zipcode`) |

SQL lives in `flink-sql/`, the schema in `schemas/app-events.avsc`.

## Who registers which schema

- `app-events-value`: Dan, from `schemas/app-events.avsc`. Ali's producer must conform to it and
  never registers schemas itself.
- `landing-orders-value`: Ida's Datagen connector registers it when it first writes.
- `curated-orders-value`: created by the Flink statement that writes the topic.

Schema Registry compatibility is `BACKWARD` (set by Omar), so an incompatible change to
`app-events.avsc` is rejected. To demonstrate, add a new field with no default to
`schemas/app-events.avsc` and run `make dan-apply`; Schema Registry refuses the new version.

## Prerequisites

- Omar, Ida, and Ali have been applied, so `.env` holds the keys listed in `required-env.txt`
  (loading fails early and names any that are missing)
- Ida's connector has written at least once, so the landing schema exists in Schema Registry
  (the Flink statement needs it)
- Terraform 1.7 or newer, `jq`

## Run

From the repository root:

```bash
make dan-plan
make dan-apply      # registers the schema and starts the statement, then publishes DAN_* keys
```

Published key: `DAN_CURATED_TOPICS` (comma-separated curated topic names).

## Tear down

```bash
make dan-destroy    # stops the statement, removes the schema, and removes DAN_* keys from .env
```

Stop Ali's microservice before destroying.

## Things to confirm on the first live apply

- **Landing schema shape.** `curate-orders.sql` assumes the Datagen Orders fields (`orderid`,
  `itemid`, `orderunits`, `ordertime`, and an `address` row with `city`, `state`, `zipcode`).
  Inspect the schema Ida's connector registered and adjust the projection if it differs.
- **Flink roles.** Dan's service account has the Flink developer role, the assigner role on
  himself, and the transactional-id grant (see Omar's `persona-access.tf`). If the statement fails
  with an authorization error, check those bindings first.
- **Statement names** must stay lowercase with hyphens; Terraform replaces a statement if its SQL
  changes.
