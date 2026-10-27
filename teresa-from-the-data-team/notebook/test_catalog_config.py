"""Offline tests for catalog_config: fake values only, no network, no files."""

import unittest

import catalog_config

SECRET = "fake-secret-0123456789"

ENV = {
    "OMAR_ORGANIZATION_ID": "11111111-2222-3333-4444-555555555555",
    "OMAR_ENVIRONMENT_ID": "env-fake1",
    "OMAR_KAFKA_CLUSTER_ID": "lkc-fake1",
    "OMAR_CLOUD_REGION": "us-east-2",
    "OMAR_TERESA_TABLEFLOW_API_KEY": "fake-key",
    "OMAR_TERESA_TABLEFLOW_API_SECRET": SECRET,
}


class BuildSettingsTest(unittest.TestCase):
    def test_endpoint_is_derived_from_org_environment_and_region(self):
        s = catalog_config.build_settings(ENV)
        self.assertEqual(
            s.properties["uri"],
            "https://tableflow.us-east-2.aws.confluent.cloud/iceberg/catalog"
            "/organizations/11111111-2222-3333-4444-555555555555/environments/env-fake1",
        )

    def test_credential_is_key_colon_secret(self):
        s = catalog_config.build_settings(ENV)
        self.assertEqual(s.properties["credential"], "fake-key:" + SECRET)

    def test_catalog_is_rest_with_vended_credentials(self):
        s = catalog_config.build_settings(ENV)
        self.assertEqual(s.properties["type"], "rest")
        self.assertEqual(s.properties["header.X-Iceberg-Access-Delegation"], "vended-credentials")

    def test_table_is_curated_orders_in_the_cluster_namespace(self):
        s = catalog_config.build_settings(ENV)
        self.assertEqual(s.table_identifier, ("lkc-fake1", "curated-orders"))

    def test_warehouse_is_absent_unless_overridden(self):
        self.assertNotIn("warehouse", catalog_config.build_settings(ENV).properties)

    def test_overrides_replace_the_endpoint_and_set_the_warehouse(self):
        env = dict(ENV, TABLEFLOW_CATALOG_ENDPOINT="https://example.invalid/catalog",
                   TABLEFLOW_CATALOG_WAREHOUSE="my-warehouse")
        props = catalog_config.build_settings(env).properties
        self.assertEqual(props["uri"], "https://example.invalid/catalog")
        self.assertEqual(props["warehouse"], "my-warehouse")

    def test_endpoint_override_makes_org_environment_and_region_optional(self):
        env = {k: v for k, v in ENV.items()
               if k not in ("OMAR_ORGANIZATION_ID", "OMAR_ENVIRONMENT_ID", "OMAR_CLOUD_REGION")}
        env["TABLEFLOW_CATALOG_ENDPOINT"] = "https://example.invalid/catalog"
        self.assertEqual(catalog_config.build_settings(env).properties["uri"],
                         "https://example.invalid/catalog")


class FailEarlyTest(unittest.TestCase):
    def test_every_missing_or_empty_key_is_named_at_once(self):
        env = dict(ENV, OMAR_KAFKA_CLUSTER_ID="")
        del env["OMAR_TERESA_TABLEFLOW_API_KEY"]
        with self.assertRaises(catalog_config.MissingConfig) as ctx:
            catalog_config.build_settings(env)
        message = str(ctx.exception)
        self.assertIn("OMAR_KAFKA_CLUSTER_ID", message)
        self.assertIn("OMAR_TERESA_TABLEFLOW_API_KEY", message)

    def test_error_text_never_contains_a_secret_value(self):
        env = dict(ENV)
        del env["OMAR_ENVIRONMENT_ID"]
        with self.assertRaises(catalog_config.MissingConfig) as ctx:
            catalog_config.build_settings(env)
        self.assertNotIn(SECRET, str(ctx.exception))
        self.assertNotIn("fake-key", str(ctx.exception))

    def test_an_empty_environment_names_all_required_keys(self):
        with self.assertRaises(catalog_config.MissingConfig) as ctx:
            catalog_config.build_settings({})
        for key in catalog_config.REQUIRED_KEYS:
            self.assertIn(key, str(ctx.exception))


class ExportedKeysTest(unittest.TestCase):
    def test_all_keys_are_exactly_the_notebook_inputs_and_overrides(self):
        self.assertEqual(
            set(catalog_config.ALL_KEYS),
            set(ENV) | {"TABLEFLOW_CATALOG_ENDPOINT", "TABLEFLOW_CATALOG_WAREHOUSE"},
        )

    def test_no_other_personas_secrets_are_in_the_list(self):
        for key in catalog_config.ALL_KEYS:
            self.assertFalse(key.startswith(("OMAR_IDA_", "OMAR_DAN_", "OMAR_ALI_")), key)
        self.assertNotIn("OMAR_ORGANIZATION_ID_SECRET", catalog_config.ALL_KEYS)


class SecretHandlingTest(unittest.TestCase):
    def test_repr_and_str_do_not_leak_the_secret(self):
        s = catalog_config.build_settings(ENV)
        self.assertNotIn(SECRET, repr(s))
        self.assertNotIn(SECRET, str(s))


class FriendlyMessageTest(unittest.TestCase):
    def test_empty_and_missing_are_plain_sentences_with_a_retry_hint(self):
        for kind in ("empty", "missing"):
            text = catalog_config.friendly_message(kind)
            self.assertNotIn("Traceback", text)
            self.assertIn("few minutes", text)

    def test_unknown_kind_is_rejected(self):
        with self.assertRaises(ValueError):
            catalog_config.friendly_message("other")


if __name__ == "__main__":
    unittest.main()
