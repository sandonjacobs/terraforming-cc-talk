<!--
Sync Impact Report
- Version change: 2.0.3 → 2.1.0
- Bump rationale: MINOR. Materially expanded guidance: a fifth persona workspace,
  `teresa-from-the-data-team/`, is added to the persona list, and the least-privilege and
  environment-file principles now name her explicitly.
- Modified principles:
  - I. Infrastructure as Code (persona list now includes `teresa-from-the-data-team/`; Tableflow
    added to the managed resource types)
  - IV. Least-Privilege Service Accounts (Teresa's account is issued by Omar, scoped to Tableflow
    on `curated-orders`)
  - VI. Personas Communicate Only Through the Environment File (`OMAR_TERESA_*` in, `TERESA_*` out)
- Modified sections: Development Workflow (apply order Omar, Ida, Ali, Dan, Teresa); Additional
  Constraints (Tableflow storage)
- Added sections: none
- Removed sections: none
- Vault check: no Vault references remain in this constitution; nothing to remove.
- Follow-up TODOs: none
-->

# Terraforming CC Constitution

## Core Principles

### I. Infrastructure as Code
All Confluent Cloud resources used in this project (environments, Kafka clusters, governance
configuration, Flink compute pools, connectors, topics, schemas, Flink statements, Tableflow
topic enablement, service accounts, role bindings, and API keys) MUST be defined declaratively in Terraform inside the
workspace of the persona that owns them: `omar-the-operator/`, `ida-the-integrator/`,
`dan-the-data-guy/`, `ali-the-app-developer/`, or `teresa-from-the-data-team/`. Manual changes made through the Confluent
Cloud console or CLI are NOT permitted for anything that is meant to persist beyond a single
ad-hoc debugging session; any such change MUST be reconciled back into Terraform before the
next `terraform apply`.
**Rationale**: This repository demonstrates how each persona on a data streaming platform uses
the Terraform provider. The demonstration's value depends on every resource shown being fully
described in code, so it can be inspected, re-run, and torn down identically every time.

### II. Secrets Never in Version Control
No API key, API secret, password, or token MAY be committed to git in plaintext, including in
`.tf`, `.tfvars`, `.tfstate`, `.env` files, scripts, or documentation. Every `.env` file in
the project MUST be matched by a `.gitignore` rule. Generated credentials MUST flow from
Terraform into the shared environment file (the project's stand-in for a secrets manager) and
MUST NOT be printed to logs or copied by hand. Organization-level credentials used to run
Omar's workspace MUST be supplied outside the repository.
**Rationale**: This is a live-demo codebase that gets shared publicly; a single leaked
credential in git history is permanent and can compromise a real Confluent Cloud organization.
The `.env` file is a deliberate simplification that keeps the demo easy to follow while still
modeling the pattern of publishing credentials to a secrets store.

### III. Reproducible, Resettable Demo Environment
The full environment MUST be bringable up from a clean checkout by applying the persona
workspaces in the dependency order documented in the quickstart, using documented steps, and
MUST be fully reversible by destroying them in reverse order. Terraform state MUST remain local and
scoped to each persona workspace so re-running the demo never depends on shared or leftover
remote state. `prevent_destroy` MUST be `false` on all demo resources. Re-running any
workspace with unchanged inputs MUST produce no changes.
**Rationale**: A talk demo that cannot be reset reliably, or that silently depends on stale
state from a previous run, is a live-demo failure waiting to happen.

### IV. Least-Privilege Service Accounts
Every Confluent Cloud service account created by this project MUST be scoped to the minimum
roles its persona needs for its tasks, using one account per responsibility rather than
reusing a broad account across personas. New service accounts or role bindings introduced to
extend the demo MUST follow the same minimum-necessary-role pattern. Omar's workspace issues
every downstream persona's service account, role bindings, and API keys, including Teresa's,
whose access MUST be limited to enabling and reading Tableflow on `curated-orders`.
**Rationale**: Least privilege is itself one of the lessons this demo teaches; the Terraform
code should model the practice it advocates.

### V. Clarity Over Abstraction
Because this codebase's primary purpose is to be read, explained, and followed along with
during a talk, Terraform and supporting code MUST favor explicit, linearly-readable resource
definitions over premature modularization (custom modules, dynamic blocks, remote state,
multi-environment workspaces) unless the abstraction is itself the point being taught.
Comments explaining *why* a resource or `depends_on` exists are encouraged; comments
restating *what* a resource obviously does are not.
**Rationale**: Audience members following along need to trace cause and effect directly in the
`.tf` files without first learning a bespoke module structure.

### VI. Personas Communicate Only Through the Environment File
Each persona workspace MUST obtain the inputs it needs from the shared environment file and
MUST publish the values it creates for others (endpoints, identifiers, topic names,
credentials) to that same file under persona-specific key names, without overwriting other
personas' values. Omar's per-persona credentials are published as `OMAR_<PERSONA>_*` keys (for
example `OMAR_TERESA_*`), and each persona's own outputs use its persona prefix (for example
`TERESA_*`). A workspace MUST NOT depend on another workspace's Terraform state, on
hand-entered values, or on direct lookups of another persona's resources, and MUST fail early
with a clear message naming any required value that is missing.
**Rationale**: A single, explicit hand-off contract keeps each persona independently runnable
and demonstrable, and makes the dependencies between roles visible to the audience.

## Additional Constraints

- **Provisioning**: Confluent Cloud resources are managed exclusively through the
  `confluentinc/confluent` Terraform provider with a minimum version (currently 2.91.0) set in
  each workspace's `required_providers`; the committed `.terraform.lock.hcl` pins the exact
  version, so bumps are deliberate changes, not incidental ones.
- **Secrets hand-off**: The gitignored shared `.env` file is the only sanctioned mechanism for
  passing credentials and platform values between personas. No alternative (committed
  `.env`/`.tfvars` files, hardcoded constants) may be substituted. Adopting a real secrets
  manager later is an amendment to this constitution.
- **Data format**: All demo topics MUST use Avro with schemas registered in the governed
  environment.
- **Tableflow storage**: Tableflow on `curated-orders` MUST use Confluent-managed storage;
  no customer storage bucket or provider integration is provisioned. Teresa's workspace owns
  the Tableflow resource, and Dan's workspace MUST NOT manage it.
- **Application code**: Ali's demo microservice MUST run locally using credentials from the
  environment file; no hosting infrastructure is provisioned for it.
- **Build tooling**: Any JVM code added to support the talk MUST build with Maven, using the
  `pom.xml` in its own module directory, rather than a second, parallel build system.
- **Schema-first Java**: Java classes for demo events MUST be generated from the schema in
  Schema Registry (downloaded at build time by the Schema Registry Maven plugin), not
  hand-written or copied from Dan's source file, except in the offline test profile.

## Development Workflow

- Before presenting or recording a demo run, verify the full cycle (apply all personas in
  order: Omar, Ida, Ali, Dan, Teresa; demo steps; destroy in reverse order) succeeds from a clean state at least once.
- Any change to a persona's Terraform MUST be reviewed for compliance with Principles I-IV and
  VI (declarative, no leaked secrets, destroyable, least-privilege, environment-file contract)
  before being merged.
- Variable defaults MUST be safe to run as-is for a first-time demo setup (no secrets as
  defaults); required values without safe defaults MUST remain required inputs sourced from the
  environment file or supplied outside the repository.
- Each persona workspace MUST document its prerequisites, how to run it, and how to tear it
  down.

## Governance

This constitution governs the practices for this talk/demo repository and supersedes ad-hoc
conventions. Amendments are made by editing this file directly, incrementing the version per
semantic versioning (MAJOR for incompatible principle removals/redefinitions, MINOR for new
principles or materially expanded guidance, PATCH for wording/clarification fixes), and
updating the Sync Impact Report at the top of the file. Pull requests that touch any persona
workspace or shared tooling MUST note in their description which principles are relevant to
the change. There is no separate runtime guidance file for this project at this time; this
constitution is the single source of governance.

**Version**: 2.1.0 | **Ratified**: 2026-10-21 | **Last Amended**: 2026-10-27
