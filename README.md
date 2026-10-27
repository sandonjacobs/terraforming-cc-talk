# Terraforming Confluent Cloud, one persona at a time

A talk demo showing how the people around a data streaming platform each use the
[Confluent Terraform provider](https://registry.terraform.io/providers/confluentinc/confluent/latest/docs)
to do their own job. Each persona has a directory, a Terraform workspace, and a README. They hand
information to each other through one gitignored `.env` file, which stands in for a secrets manager.

| Persona | Directory | Job |
|---------|-----------|-----|
| Omar the Operator | [`omar-the-operator`](omar-the-operator) | Environment (Advanced governance), Standard Kafka cluster, Flink compute pool in AWS `us-east-2`, plus credentials and role bindings for everyone else |
| Ida the Integrator | [`ida-the-integrator`](ida-the-integrator) | A managed Datagen connector generating sample orders into the `landing-orders` topic as Avro |
| Ali the App Developer | [`ali-the-app-developer`](ali-the-app-developer) | The `app-events` topic and a local Java producer |
| Dan the Data Guy | [`dan-the-data-guy`](dan-the-data-guy) | Avro schema for Ali's events and a Flink SQL transformation of the orders |
| Teresa from the data team | [`teresa-from-the-data-team`](teresa-from-the-data-team) | Tableflow on `curated-orders`, so the data is an Iceberg table for reporting (Confluent-managed storage), plus a notebook that charts it |

Topic names use hyphens, never dots: `landing-*` (Ida), `app-*` (Ali), `curated-*` (Dan).

## Run the demo

You need Terraform 1.7+, `jq`, `make`, JDK 21, and Maven 3.9+. Export your organization-level
credentials (never in the repo):

```bash
export CONFLUENT_CLOUD_API_KEY=...
export CONFLUENT_CLOUD_API_SECRET=...
```

Then one command per step (applies and destroys run with `-auto-approve`, so nothing stops to ask):

```bash
make help           # every target
make check          # offline checks, no cloud calls

make omar-apply     # 1. the platform
make ida-apply      # 2. connector and landing topic
make ali-apply      # 3. the app topic
make dan-apply      # 4. schema and Flink statements
make teresa-apply   # 5. Tableflow turns curated-orders into an Iceberg table
make teresa-notebook # chart of curated-orders from that table (optional, any time after 5)
make ali-run        # 6. start Ali's producer (Ctrl-C to stop)

make demo-up        # steps 1 to 5 in one go
```

Tear down in reverse order (stop Ali's producer first):

```bash
make teresa-destroy && make dan-destroy && make ali-destroy && make ida-destroy && make omar-destroy
# or
make demo-down
```

`make <persona>-plan` previews any step, and `make env-keys` lists which keys `.env` holds (names
only, never values).

## How the hand-off works

Each `<persona>-apply` loads only the keys that persona needs from `.env` (listed in the
persona's `required-env.txt`; it stops early and names any that are missing), runs Terraform, and
publishes the persona's outputs back into `.env` under its own prefix (`OMAR_`, `IDA_`, `ALI_`,
`DAN_`, `TERESA_`). Each `<persona>-destroy` removes that persona's keys. The key list is in
[`.env.example`](.env.example) and the contract is in
[`specs/001-persona-terraform-demo/contracts/env-file-contract.md`](specs/001-persona-terraform-demo/contracts/env-file-contract.md).

Apply order is Omar, Ida, Ali, Dan, Teresa, then Ali's producer, because Dan needs the topics Ida and
Ali create, Teresa needs the `curated-orders` topic Dan creates, and Ali's producer needs the schema
Dan registers.

## Safety

- `.env`, Terraform state, and `.terraform/` are gitignored. Only `.env.example` (no values) is
  tracked.
- Terraform state is local to each persona directory.
- These workspaces create paid Confluent Cloud resources (a Standard cluster and a Flink pool).
  Tear down when you are done.

Design documents: [`specs/001-persona-terraform-demo`](specs/001-persona-terraform-demo).
