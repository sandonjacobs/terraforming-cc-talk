# Dan owns the data contract for Ali's events. The orders landing schema is registered by Ida's
# connector, and the curated topics' schemas are created by the Flink statements that write them.

resource "confluent_schema" "app_events" {
  subject_name = "${var.ali_events_topic}-value"
  format       = "AVRO"
  schema       = file("${path.module}/schemas/app-events.avsc")

  # Remove the subject completely on destroy so the demo can be re-run from scratch.
  hard_delete = true

  schema_registry_cluster {
    id = var.omar_schema_registry_id
  }

  rest_endpoint = var.omar_schema_registry_rest_endpoint

  credentials {
    key    = var.omar_dan_schema_registry_api_key
    secret = var.omar_dan_schema_registry_api_secret
  }

  lifecycle {
    prevent_destroy = false
  }
}
