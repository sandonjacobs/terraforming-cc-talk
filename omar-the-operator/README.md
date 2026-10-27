# Omar the Operator

Omar administers the data streaming platform. This workspace provisions the shared foundation in
AWS `us-east-1` and hands everything the other personas need to them through the root `.env`.

## What it creates

- Confluent Cloud environment with the **Advanced** Stream Governance package
- **Standard** Kafka cluster
- Flink compute pool (`flink_max_cfu`, default 5)
- Schema Registry compatibility policy `BACKWARD`
- A service account, role bindings, and API keys for each downstream persona, scoped by topic
  prefix:

| Persona | Owns | Access |
|---------|------|--------|
| Ida | `landing-*` topics | `CloudClusterAdmin` on the cluster (see trade-off below), write `landing-*` subjects; Kafka and Cloud API keys |
| Ali | `app-*` topics | Manage and write `app-*` topics, read `app-*` subjects; Kafka and Schema Registry keys |
| Dan | `curated-*` topics | Read `landing-*` and `app-*`; read, write, and manage `curated-*`; write `app-*` and `curated-*` subjects, read `landing-*` subjects; Flink developer; Kafka, Schema Registry, and Flink keys |

## Prerequisites

- Terraform 1.7 or newer, `jq`
- Organization-level credentials exported in your shell (never in the repo):

  ```bash
  export CONFLUENT_CLOUD_API_KEY=...
  export CONFLUENT_CLOUD_API_SECRET=...
  export TF_VAR_organization_id=...   # your organization's UUID
  ```

  The organization ID is Omar's `organization_id` variable. He publishes it as `OMAR_ORGANIZATION_ID`, which the other personas read from `.env`.

## Run

From the repository root:

```bash
make omar-plan      # preview
make omar-apply     # create, then publish the OMAR_* keys to .env
```

Under the hood `omar-apply` runs `terraform apply` here and then
`../scripts/publish-env.sh . OMAR`. Terraform state stays local in this directory.

## Tear down

```bash
make omar-destroy   # destroys everything here and removes the OMAR_* keys from .env
```

Destroy the other personas first (`make demo-down` does the whole sequence in order).

## Trade-offs and things to confirm

- **Ida's role.** Managing managed connectors through the Cloud API is given `CloudClusterAdmin` on
  the cluster. That is broader than Ida's `landing-*` scope. If a narrower role that can manage
  connectors exists in your organization, swap it in `persona-access.tf` (`ida_cluster_admin`).
- **Role names and CRN patterns** for prefixed topic and subject bindings, the Flink transactional-id
  grant, and the Assigner binding follow Confluent's documented patterns but have not been applied
  to a live organization yet. If an apply is rejected, the role bindings in `persona-access.tf` are
  the place to adjust.
- **Why Standard, not Enterprise.** Enterprise clusters require private networking (a PrivateLink
  access point; without one the console shows "Cluster networking setup incomplete"), which a laptop
  cannot reach. Standard is public, so Terraform, managed connectors, Flink and Ali's local producer
  all connect with no networking resources.
- **Teresa's access.** Her service account has `ResourceOwner` on the single topic `curated-orders`
  and `DeveloperRead` on all schema subjects (Tableflow reads the topic's schema). Managed storage
  needs neither `Assigner` nor `CloudClusterAdmin`, so she has neither. She gets a Kafka API key
  and a Tableflow API key, published as `OMAR_TERESA_*`. The binding names the exact topic rather
  than `curated-*` so she cannot enable Tableflow on anything else (Principle IV, SC-009); if Dan
  renames his `curated_orders_topic`, change `teresa_bindings` in `persona-access.tf` to match.
  Two things to confirm on the first live apply: that a binding on a topic Dan has not created
  yet is accepted (if not, apply the binding after Dan, never widen it to a prefix), and the
  `managed_resource` values of the Tableflow API key.
