"""Turns the shared .env values into PyIceberg settings for Teresa's notebook.

This is the notebook's only logic, kept out of the notebook so it can be tested offline. It uses
only the standard library. The endpoint form, the warehouse, and the namespace are unconfirmed
(research.md items 18 and 19): each lives in one place below, and the two TABLEFLOW_CATALOG_*
overrides let the demo work before the defaults are corrected.
"""

import os
import sys
from dataclasses import dataclass

CATALOG_NAME = "tableflow"
TABLE_NAME = "curated-orders"

# Teresa's own key and the cluster that holds the table; always needed.
ALWAYS_REQUIRED = (
    "OMAR_KAFKA_CLUSTER_ID",
    "OMAR_TERESA_TABLEFLOW_API_KEY",
    "OMAR_TERESA_TABLEFLOW_API_SECRET",
)
# Only needed to derive the endpoint, so an endpoint override makes them optional.
ENDPOINT_REQUIRED = ("OMAR_ORGANIZATION_ID", "OMAR_ENVIRONMENT_ID", "OMAR_CLOUD_REGION")
REQUIRED_KEYS = ALWAYS_REQUIRED + ENDPOINT_REQUIRED

ENDPOINT_OVERRIDE = "TABLEFLOW_CATALOG_ENDPOINT"
WAREHOUSE_OVERRIDE = "TABLEFLOW_CATALOG_WAREHOUSE"

# Everything the notebook may read. The Makefile exports only these from .env, so the kernel never
# sees other personas' secrets.
ALL_KEYS = REQUIRED_KEYS + (ENDPOINT_OVERRIDE, WAREHOUSE_OVERRIDE)

# The demo cluster is on AWS; .env has no cloud-provider key.
ENDPOINT_TEMPLATE = (
    "https://tableflow.{region}.aws.confluent.cloud/iceberg/catalog"
    "/organizations/{org}/environments/{env}"
)

MESSAGES = {
    "empty": "The curated-orders table has no rows yet. Tableflow materializes a low-throughput "
             "topic every few minutes; make sure the producers are running, wait a few minutes, "
             "and run this cell again.",
    "missing": "The curated-orders table is not available yet. Tableflow may not have "
               "materialized it: check that Teresa's workspace is applied, wait a few minutes, "
               "and run this cell again.",
}


class MissingConfig(Exception):
    """Raised with every missing value named, so the presenter fixes them in one pass."""


@dataclass(frozen=True)
class Settings:
    catalog_name: str
    properties: dict
    table_identifier: tuple

    def __repr__(self):
        shown = {k: ("<hidden>" if k == "credential" else v) for k, v in self.properties.items()}
        return f"Settings(catalog_name={self.catalog_name!r}, properties={shown!r}, " \
               f"table_identifier={self.table_identifier!r})"

    __str__ = __repr__


def build_settings(env):
    override = env.get(ENDPOINT_OVERRIDE, "")
    needed = ALWAYS_REQUIRED if override else REQUIRED_KEYS
    missing = [key for key in needed if not env.get(key)]
    if missing:
        raise MissingConfig(
            "Missing from .env: " + ", ".join(missing) + ". Apply the upstream personas first "
            "(make demo-up), then run this again."
        )

    uri = override or ENDPOINT_TEMPLATE.format(
        region=env["OMAR_CLOUD_REGION"],
        org=env["OMAR_ORGANIZATION_ID"],
        env=env["OMAR_ENVIRONMENT_ID"],
    )
    properties = {
        "type": "rest",
        "uri": uri,
        "credential": f"{env['OMAR_TERESA_TABLEFLOW_API_KEY']}:{env['OMAR_TERESA_TABLEFLOW_API_SECRET']}",
        # Managed storage is read with credentials the catalog hands out (research.md item 18c).
        "header.X-Iceberg-Access-Delegation": "vended-credentials",
    }
    if env.get(WAREHOUSE_OVERRIDE):
        properties["warehouse"] = env[WAREHOUSE_OVERRIDE]
    return Settings(CATALOG_NAME, properties, (env["OMAR_KAFKA_CLUSTER_ID"], TABLE_NAME))


def load_settings():
    return build_settings(os.environ)


def friendly_message(kind):
    if kind not in MESSAGES:
        raise ValueError(f"unknown message kind: {kind!r}")
    return MESSAGES[kind]


if __name__ == "__main__":
    # `make teresa-notebook` asks for the key names to export, then runs this once so missing
    # values fail before Jupyter starts.
    if sys.argv[1:] == ["--keys"]:
        print("\n".join(ALL_KEYS))
        sys.exit(0)
    try:
        settings = load_settings()
    except MissingConfig as error:
        sys.exit(str(error))
    print(f"Catalog settings OK for table {'.'.join(settings.table_identifier)}")
