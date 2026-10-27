# Feature Specification: Persona-Based Confluent Cloud Terraform Demo

**Feature Branch**: `txc`

**Created**: 2026-10-21

**Status**: Draft

**Input**: User description: "Refactor this project to depict a demo for the various personas involved in using the data streaming platform on Confluent Cloud - each using the Terraform Provider to perform a task. Omar the Operator provisions the platform (environment, Standard Kafka cluster, Advanced data governance, Flink compute pool in AWS us-east-1) and publishes credentials and role bindings to a shared environment file. Ida the Integrator provisions a managed Datagen connector and landing topic for generated orders. Dan the Data Guy defines schemas and deploys Flink SQL transformations. Ali the App Developer builds a microservice that produces more data to topics Dan may use. Each persona works from its own directory and consumes the information the previous personas published."

## Clarifications

### Session 2026-10-21

- Q: Should Ida and Ali also write the details they create (topic names, credentials) back into the shared environment file so Dan can pick them up, or should Dan look them up from Confluent Cloud? → A: Every persona appends its outputs to the shared environment file; downstream personas read only from that file.
- Q: Which data format should the demo's Kafka messages and schemas use? → A: Avro for all topics.
- Q (user direction, later in session): Which free API and polling cadence, and what topic naming? → A: *Superseded below.* No dots in topic names, hyphens only.

### Session 2026-10-22

- Q (user direction): Should Ida still call the BART API? → A: No. Ida uses the managed Datagen Source connector's Orders quickstart to generate order records into one landing topic as Avro. No external API, API key, or polling cadence is involved. Dan is reduced to one schema (Ali's events) and one Flink statement over the orders; Ali keeps the microservice, with BART-specific fields removed and its use case to be decided.
- Q: Where should Ali's demo microservice run when presenting? → A: Locally on the presenter's machine, using credentials from the environment file.

### Session 2026-10-27

- Q (user direction): A fifth persona, Teresa from the data team, needs the `curated-orders` data in Iceberg format for reporting. Where should the table data be stored? → A: Confluent-managed storage; no customer S3 bucket or provider integration is provisioned.
- Q: Who owns enabling Tableflow on `curated-orders`: Dan (topic owner) or Teresa? → A: Teresa, in her own workspace, with her own service account and credentials issued by Omar. Dan's workspace is unchanged.
- Q (user direction): How should Teresa see the table for the demo? → A: A local Jupyter notebook that reads `curated-orders` through the Tableflow Iceberg REST catalog with PyIceberg and shows it visually. It is a read-only consumer: no new Terraform resources, roles, or keys.
- Q: Where does the notebook get its configuration? → A: Only from the shared environment file (Teresa's Tableflow key and secret, plus the organization, environment, cluster, and region values), with an optional override for the catalog endpoint. Nothing is hardcoded or typed in by hand.
- Q: Where does the notebook run? → A: Locally on the presenter's machine, like Ali's microservice; no hosting is provisioned.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Omar provisions the platform (Priority: P1)

Omar, the platform operator, runs his workflow once to stand up the shared Confluent Cloud foundation: an environment with advanced data governance, an standard-tier Kafka cluster, and a Flink compute pool, all in AWS us-east-2. He also creates the service accounts, API keys, and role bindings that the other personas need. When finished, everything the other personas need (endpoints, identifiers, credentials) is written to a single local environment file that is excluded from version control.

**Why this priority**: Every other persona depends on this foundation. Without it, nothing else in the demo can run, so it is the minimum viable demo.

**Independent Test**: Run only Omar's workflow against an empty Confluent Cloud organization and confirm the environment, cluster, governance package, and compute pool exist in us-east-2, and that the environment file contains all published values.

**Acceptance Scenarios**:

1. **Given** an empty Confluent Cloud organization and valid organization-level credentials, **When** Omar runs his workflow, **Then** an environment with advanced governance, a standard Kafka cluster, and a Flink compute pool exist in AWS us-east-2.
2. **Given** Omar's workflow has completed, **When** the shared environment file is inspected, **Then** it contains the cluster endpoint, schema registry endpoint, compute pool and environment identifiers, and credentials for each downstream persona.
3. **Given** Omar's workflow has completed, **When** repository status is checked, **Then** the environment file is not tracked and cannot be accidentally committed.
4. **Given** Omar has already provisioned the platform, **When** he re-runs his workflow with no changes, **Then** no resources are changed.

---

### User Story 2 - Ida brings external data in through managed connectors (Priority: P2)

Ida, the integration specialist, uses the values Omar published to provision a managed connector that generates sample order records into Kafka, along with the landing topic the data arrives in. The connector is Confluent Cloud's Datagen Source using its Orders quickstart, which writes order records to the topic as Avro. No external API or API key is needed.

**Why this priority**: It supplies the first real data stream, which Dan's schemas and transformations depend on.

**Independent Test**: With Omar's environment file in place, run only Ida's workflow and confirm the landing topic exists and the connector is running and delivering records.

**Acceptance Scenarios**:

1. **Given** Omar's environment file exists, **When** Ida runs her workflow, **Then** she needs to supply no Confluent Cloud identifiers or credentials by hand.
2. **Given** Ida's workflow has completed, **When** the landing topic is inspected, **Then** generated order records are arriving.
3. **Given** the environment file is missing or incomplete, **When** Ida runs her workflow, **Then** it fails early with a message identifying which required values are absent.

---

### User Story 3 - Dan defines schemas and Flink transformations (Priority: P3)

Dan, the data guy, defines schemas for the data streams he and Ali own (Ali's events and Dan's derived streams; the orders landing schema is registered by Ida's connector and consumed by Dan) and deploys a Flink SQL statement that transforms the orders into a derived stream, using the compute pool and governance Omar provisioned.

**Why this priority**: It delivers the demo's analytical payoff but requires data and platform from the earlier personas.

**Independent Test**: With the platform and at least one landing topic present, run only Dan's workflow and confirm schemas are registered and the Flink statements are running and producing output records.

**Acceptance Scenarios**:

1. **Given** the platform and a landing topic exist, **When** Dan runs his workflow, **Then** schemas for the data streams are registered in the governed environment.
2. **Given** schemas are registered, **When** Dan's Flink statements are deployed, **Then** they run on Omar's compute pool and write transformed records to output topics.
3. **Given** a schema change violating the environment's compatibility policy, **When** Dan applies it, **Then** it is rejected.

---

### User Story 4 - Ali produces application data (Priority: P4)

Ali, the application developer, builds a small microservice that publishes additional data to Kafka topics that Dan can use in his transformations. Ali's workflow provisions the topics and application-scoped credentials, and obtains connection details from the shared environment file.

**Why this priority**: It enriches the demo with a second data source but is not required for the core operator → integrator → data flow.

**Independent Test**: Run only Ali's workflow and microservice, and confirm records appear on his topics using only the permissions granted to his application.

**Acceptance Scenarios**:

1. **Given** the platform exists, **When** Ali runs his workflow, **Then** his topics and application credentials are created with access limited to what his application needs.
2. **Given** Ali's microservice is running, **When** it produces data, **Then** records conforming to the registered schema appear on his topics.
3. **Given** Ali's credentials, **When** he attempts to access topics outside his application's scope, **Then** access is denied.

---

### User Story 5 - Teresa gets curated orders as an Iceberg table (Priority: P5)

Teresa, from the data team, wants the data in the `curated-orders` topic available as an Iceberg table so she can use it for reporting. She works from her own workspace, `teresa-from-the-data-team`, and turns on Tableflow for `curated-orders` using the values and credentials Omar published. The table data is kept in Confluent-managed storage, so Teresa does not need a cloud storage bucket or any storage integration. Her service account has only the access needed to enable and read that one topic's table. For the talk, she also has a local notebook that reads the table and shows the orders visually (a chart of orders by place and a short table of recent orders), so the audience sees the Iceberg data without any extra tooling.

**Why this priority**: It extends the story past streaming into analytics, but it depends on every earlier persona, especially Dan's `curated-orders` topic.

**Independent Test**: With Omar's platform and Dan's `curated-orders` topic present, run only Teresa's workflow and confirm Tableflow is enabled on `curated-orders` with Iceberg as the table format and that her outputs are published to the environment file.

**Acceptance Scenarios**:

1. **Given** Omar's and Dan's workflows have completed, **When** Teresa runs her workflow, **Then** she supplies no Confluent Cloud identifiers or credentials by hand.
2. **Given** Teresa's workflow has completed, **When** the `curated-orders` topic is inspected, **Then** Tableflow is enabled on it with Iceberg as the table format and Confluent-managed storage.
3. **Given** Tableflow is enabled and `curated-orders` is receiving records, **When** Teresa checks the table, **Then** the curated order records are available as Iceberg table data.
4. **Given** Teresa's credentials, **When** she attempts to enable Tableflow on, or administer, a topic or resource other than her granted scope, **Then** access is denied.
5. **Given** Dan's workflow has not run and `curated-orders` does not exist, **When** Teresa runs her workflow, **Then** it fails early with a message that `curated-orders` must exist first.
6. **Given** Teresa has already enabled Tableflow, **When** she re-runs her workflow with no changes, **Then** no resources are changed.
7. **Given** Teresa's workflow has completed and the table holds records, **When** the presenter launches the notebook with one documented command and runs it, **Then** it shows a chart of orders by place and a table of recent orders drawn from the Iceberg table, with no value entered by hand.
8. **Given** the table exists but is empty or not yet materialized, **When** the notebook is run, **Then** it shows a clear message saying so and how to retry, not an error trace.
9. **Given** a required value is missing from the environment file, **When** the notebook starts, **Then** it stops early and names every missing value.
10. **Given** the repository's tracked files, **When** they are inspected after the notebook has been run and committed, **Then** no secret or saved output from a run is present in them.
11. **Given** the notebook runs, **When** its permissions are examined, **Then** it only reads the table using Teresa's own credentials and creates no cloud resources, roles, or keys.

---

### Edge Cases

- A persona's workflow is run before its upstream personas have run (missing or partial environment file).
- Omar re-runs his workflow after credentials are rotated or resources were changed outside Terraform.
- The environment file already contains values from a previous demo run (stale values after teardown and re-provision).
- Resources for downstream personas still exist when Omar tears down the platform.
- Cluster or Flink pool provisioning takes longer than expected during a live demo.
- The Datagen connector cannot register its Avro schema because Ida lacks Schema Registry access for `landing-*` subjects.
- Teresa applies before Dan has created `curated-orders` (the topic does not exist yet).
- Dan's workspace is destroyed while Tableflow is still enabled on `curated-orders` (Teresa must be torn down first).
- Tableflow is not available in the cluster's region or the organization's quota or entitlements do not allow it.
- `curated-orders` has no records yet when Teresa enables Tableflow, so the table is empty until data arrives.
- The notebook is run before Tableflow has materialized any data, or before `curated-orders` has records.
- The notebook is launched with the environment file missing or incomplete, or with the Python environment not yet set up.
- The notebook was run and saved with outputs that contain data or connection details, then committed.
- The catalog endpoint cannot be derived from the environment file values (for example in a different cloud or region), so an override must be possible.
- A persona re-runs its workflow and must update its own published values in the shared environment file without disturbing values from other personas.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST be organized into five self-contained persona workspaces named `omar-the-operator`, `ida-the-integrator`, `dan-the-data-guy`, `ali-the-app-developer`, and `teresa-from-the-data-team`, each runnable independently using the Confluent Terraform provider.
- **FR-002**: Omar's workspace MUST provision a Confluent Cloud environment with the advanced data governance package.
- **FR-003**: Omar's workspace MUST provision an standard-tier Kafka cluster in AWS us-east-2.
- **FR-004**: Omar's workspace MUST provision a Flink compute pool in AWS us-east-2 within the same environment.
- **FR-005**: Omar's workspace MUST create the service accounts, API keys, and role bindings each downstream persona needs, scoped to the minimum privileges for that persona's tasks.
- **FR-006**: Omar's workspace MUST publish all values downstream personas need (endpoints, identifiers, API keys and secrets) to a single local environment file.
- **FR-007**: All environment files MUST be excluded from version control by an ignore rule covering every `.env` file in the project.
- **FR-008**: Each downstream persona's workspace MUST obtain its required inputs from the environment file rather than from hand-entered values, hardcoded values, or direct lookups against Confluent Cloud.
- **FR-008a**: Ida's and Ali's workspaces MUST each publish the values they create (such as topic names and application credentials) to the shared environment file under persona-specific key names, without overwriting values published by other personas, so that Dan's workspace can obtain the topic names it needs from that file alone.
- **FR-009**: Each downstream workspace MUST fail early with a clear message naming any required value missing from the environment file.
- **FR-010**: Ida's workspace MUST provision one managed Datagen Source connector using the Orders quickstart, writing Avro records to a single landing topic (`landing-orders`). The record rate MUST be configurable and default to a low rate suited to a live demo. No external API credentials are required.
- **FR-010a**: Topic names MUST NOT contain dots; words are separated by hyphens (for example `landing-orders`), and ownership prefixes use a hyphen (`landing-`, `app-`, `curated-`).
- **FR-011**: Dan's workspace MUST register Avro schemas for the streams he and Ali own (Ali's application topic and Dan's derived topics) in the governed environment, the landing topic's Avro schema MUST be registered in the same environment by Ida's connector, and all demo topics (Ida's landing topics, Ali's topics, and Dan's output topics) MUST use Avro.
- **FR-012**: Dan's workspace MUST deploy a Flink SQL statement that transforms the landed orders into a derived output topic (`curated-orders`).
- **FR-013**: Ali's workspace MUST provision the topics and application-scoped credentials used by a demo microservice, and the repository MUST include that microservice, which produces data to topics Dan can consume. The microservice runs locally on the presenter's machine using credentials from the environment file; Ali's workspace MUST NOT provision any hosting for it.
- **FR-014**: Each persona's workspace MUST include brief instructions for its prerequisites, how to run it, and how to tear it down.
- **FR-015**: Running any persona's workflow repeatedly with unchanged inputs MUST produce no changes after the first run.
- **FR-016**: Tearing down the full demo MUST be possible by tearing down persona workspaces in reverse dependency order, removing all provisioned Confluent Cloud resources.
- **FR-018**: Omar's workspace MUST create Teresa's service account, API keys (including any key needed to manage Tableflow), and role bindings, scoped to the minimum privileges needed to enable and read Tableflow on `curated-orders`, and MUST publish them to the shared environment file under `OMAR_TERESA_*` key names.
- **FR-019**: Teresa's workspace MUST enable Tableflow on the `curated-orders` topic with Iceberg as the table format, using Confluent-managed storage. It MUST NOT require or provision a customer storage bucket or storage provider integration.
- **FR-020**: Teresa's workspace MUST obtain all required inputs, including the `curated-orders` topic name, from the shared environment file, MUST publish the values it creates to that file under `TERESA_` key names without disturbing other personas' values, and MUST fail early with a clear message naming any missing value.
- **FR-021**: Teresa's workspace MUST own the Tableflow resource; Dan's workspace MUST NOT enable or manage Tableflow.
- **FR-022**: Teresa's workspace MUST fail early, with a clear message, if `curated-orders` does not exist.
- **FR-023**: Teresa's workspace MUST include a notebook that reads the `curated-orders` table through the Tableflow catalog and shows the orders visually (a chart of orders by place and a table of recent orders), runnable on the presenter's machine with one documented command.
- **FR-024**: The notebook MUST obtain every value it needs (Teresa's Tableflow key and secret, and the organization, environment, cluster, and region values that locate the catalog) from the shared environment file, MUST allow the catalog endpoint and warehouse to be overridden, and MUST NOT contain or require any hand-entered or hardcoded value.
- **FR-025**: The notebook MUST authenticate with Teresa's own Tableflow credentials only and MUST be read-only: it MUST NOT create, change, or delete any Confluent Cloud resource, role binding, or key.
- **FR-026**: The notebook MUST stop early with a message naming every required value missing from the environment file, and MUST show a clear message (not an error trace) when the table is empty or not yet available.
- **FR-027**: No secret MUST appear in the notebook file or in any saved notebook output, and committed notebooks MUST have their outputs cleared; this MUST be verifiable without a Confluent Cloud account.
- **FR-028**: The notebook's setup (its Python environment and the logic that turns environment file values into catalog connection settings) MUST be documented in Teresa's README and checkable offline, using fake values and no network access.
- **FR-017**: The existing single-directory configuration (`cc-terraform-base`) MUST be replaced by the persona-based structure, with its still-relevant resources migrated into Omar's workspace.

### Key Entities

- **Persona**: A role in the demo (Operator, Integrator, Data Guy, App Developer, Data Team Analyst) with its own workspace, responsibilities, and level of access.
- **Shared Environment File**: A local, untracked file that carries platform values and credentials between personas; every persona publishes its outputs to it and downstream personas read only from it. It stands in for a secrets manager.
- **Platform Foundation**: The environment, governance package, Kafka cluster, and Flink compute pool owned by Omar.
- **Persona Credentials**: Service account, API key, and role bindings issued per persona with minimum necessary access.
- **Connector and Landing Topic**: Ida's Datagen connector and the landing topic of generated orders.
- **Schema and Flink Statement**: Dan's data contracts and streaming transformations.
- **Application Topic and Microservice**: Ali's producer application and the topics it writes to.
- **Demo Notebook**: Teresa's local, read-only notebook that reads the Tableflow Iceberg table using values from the shared environment file and shows the orders as a chart and a table.
- **Tableflow Iceberg Table**: Teresa's Iceberg representation of the `curated-orders` topic, kept in Confluent-managed storage and used for reporting.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A presenter can bring the full demo from an empty organization to all five personas complete by following the documented steps, with no values copied by hand between workspaces.
- **SC-002**: 100% of credentials and secrets generated during the demo are absent from the repository's tracked files after a complete run.
- **SC-003**: Each persona's workflow can be run and demonstrated on its own, given only the values published by the personas upstream of it.
- **SC-004**: After a full run, generated orders are visible on the landing topic, and Dan's transformed output records are visible on an output topic.
- **SC-005**: A full teardown leaves zero demo resources in the Confluent Cloud organization.
- **SC-006**: A second run of any persona's workflow with unchanged inputs reports zero changes.
- **SC-007**: A new audience member can identify each persona's directory and responsibility from the project documentation within two minutes.
- **SC-008**: After Teresa's workflow completes, the `curated-orders` data is available to her as an Iceberg table, with no storage bucket or credentials created or entered by hand.
- **SC-009**: Teresa's credentials cannot enable Tableflow on, or read, any topic other than `curated-orders`.
- **SC-010**: From a populated table, the presenter can launch the notebook and show a chart and a table of orders to the audience within two minutes, with no value copied by hand.
- **SC-011**: 100% of notebook runs with missing configuration or an empty table end with a plain-language message, with no error trace shown to the audience.
- **SC-012**: Zero secrets and zero saved run outputs are present in the repository's tracked notebook and supporting files after a complete demo run, checkable offline.

## Assumptions

- The demo is for conference/talk use and runs in a single Confluent Cloud organization the presenter controls.
- A `.env` file is an acceptable stand-in for a secrets manager for now; replacing it with a real secrets manager is out of scope. This supersedes the Vault-based approach in the current repository and in the project constitution, which will need a follow-up amendment.
- Omar's workflow is run with organization-level credentials supplied by the presenter outside the repository.
- Persona workspaces are applied in order Omar, Ida, Ali, Dan, then Teresa, and torn down in the reverse order; Teresa must apply after Dan because `curated-orders` must already exist. Ali's microservice may run before or after Dan's work, but Dan's statements need data to be present to show output.
- The managed Datagen Source connector (Orders quickstart) is the data source, so the demo has no external dependency or API key.
- The Flink SQL statements and schemas will be simple, illustrative examples sized for a live demo.
- Ali's microservice is a small demonstration application, not production code, and its implementation language will be chosen during planning.
- Confluent Cloud account quotas allow a standard cluster, advanced governance, and a Flink pool in us-east-2.
- Terraform state remains local per persona workspace, consistent with the existing project approach.
- Tableflow is available for the demo's Standard cluster and region. Reporting-tool access is limited to Teresa's demo notebook; wiring the table to any other reporting or BI tool remains out of scope (this amends the earlier assumption that reporting access was out of scope).
- The notebook is user-directed to use PyIceberg and Jupyter, runs locally like Ali's microservice, and shows its results from the table as it stands when run; it does not refresh live.
- The catalog endpoint can normally be derived from the organization, environment, and region values in the environment file; the exact form is confirmed during planning, and an override covers any case it cannot.
- The project constitution (Principle I persona list and Principle IV) will need a follow-up amendment to add Teresa's workspace; that is done in a later step.
