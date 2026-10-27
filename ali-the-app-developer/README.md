# Ali the App Developer

Ali builds the application that produces more data for Dan to use. This directory has two parts:

- **Terraform** (this directory): creates the `app-events` topic with Ali's own credentials.
- **Microservice** (`service/`): a small Java 21 producer that runs **locally** and sends synthetic
  application events (created, updated, deleted) as Avro. The use case is still to be decided. Its Java classes are generated from the schema Dan registered.

Topic names use hyphens only (no dots) and start with `app-`, the prefix Omar scoped Ali's access
to.

## Terraform

### Prerequisites

- Omar has been applied (`make omar-apply`), so `.env` holds the keys in `required-env.txt`
  (loading fails early and names any that are missing)
- Terraform 1.7 or newer, `jq`

### Run

From the repository root:

```bash
make ali-plan
make ali-apply      # creates the topic, then publishes ALI_EVENTS_TOPIC to .env
```

### Tear down

```bash
make ali-destroy    # removes the topic and the ALI_* keys from .env
```

Stop the microservice before destroying.

## Microservice

The producer sends one event per second (set `APP_EVENTS_INTERVAL_MS` to change it) to the topic in
`ALI_EVENTS_TOPIC`, using Ali's credentials from `.env`. It never registers schemas: it uses the
`app-events-value` schema Dan registered, and the build fails if that schema is not there.

### How the schema gets into the code

The Maven build in `service/pom.xml` has two steps, in order:

1. `kafka-schema-registry-maven-plugin` (`download`) fetches the `${ALI_EVENTS_TOPIC}-value`
   subject from Schema Registry with Ali's credentials into `service/target/schemas/`.
2. `avro-maven-plugin` (`schema`) generates `AppEvent` from it into
   `service/target/generated-sources/avro/`.

`EventGenerator` builds `AppEvent` objects, so if Dan changes the schema in an incompatible way,
Ali finds out at compile time. Run just these two steps with `make ali-schemas`.

### Prerequisites

- Omar, Ida, Ali, and then **Dan** have been applied, so the schema exists
- JDK 21 and Maven 3.9 or newer, with network access to Maven Central and `packages.confluent.io`

### Run

```bash
make ali-schemas    # optional: download Dan's schema and generate the classes
make ali-run
```

`make ali-run` loads `.env` into the environment, downloads the schema, generates the classes,
then compiles and runs the service. Stop it with Ctrl-C.
It reads these variables: `OMAR_KAFKA_BOOTSTRAP_ENDPOINT`, `OMAR_ALI_KAFKA_API_KEY`,
`OMAR_ALI_KAFKA_API_SECRET`, `OMAR_SCHEMA_REGISTRY_REST_ENDPOINT`,
`OMAR_ALI_SCHEMA_REGISTRY_API_KEY`, `OMAR_ALI_SCHEMA_REGISTRY_API_SECRET`, `ALI_EVENTS_TOPIC`, and
fails at startup naming any that are missing. The same variables drive the schema download.

### Show least privilege

Ali's credentials only cover `app-*` topics. Producing to a `landing-*` or `curated-*` topic with
them should fail with an authorization error.

### Test (offline)

```bash
mvn -q -f ali-the-app-developer/service/pom.xml -Doffline test
```

`-Doffline` copies `dan-the-data-guy/schemas/app-events.avsc` instead of calling Schema Registry,
so the tests need no credentials. `make check` runs them this way.
