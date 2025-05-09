resource "confluent_connector" "noaa_zones_source" {
  environment {
    id = local.confluent_env.id
  }
  kafka_cluster {
    id = local.kafka.cluster_id
  }

  config_sensitive = {}

  config_nonsensitive = {
    "connector.class"          = "HttpSource"
    "name"                     = "http_src_noaa_zones"
    "kafka.auth.mode"          = "KAFKA_API_KEY"
    "kafka.api.key"            = local.sa_kafka_manager.api_key_id
    "kafka.api.secret"         = local.sa_kafka_manager.api_key_secret
    "kafka.topic"              = confluent_kafka_topic.noaa_zones_inbound.topic_name
    "output.data.format"       = "AVRO"
    "tasks.max"                = "1"
    "topic.name.pattern"       = confluent_kafka_topic.noaa_zones_inbound.topic_name
    "url"                      = "https://api.weather.gov/zones"
    "http.offset.mode"         = "SIMPLE_INCREMENTING"
    "http.initial.offset"      = "0"
    "http.response.data.json.pointer" = "/features"
    "request.interval.ms"      = 600000

    "transforms"                            = "DropUnusedFields,Flatten,RenameFields,DropUnusedFlattenedFields,MakeEventKey"
    "transforms.DropUnusedFields.type"      = "org.apache.kafka.connect.transforms.ReplaceField$Value"
    "transforms.DropUnusedFields.exclude"   = "id,type"

    "transforms.Flatten.type"               = "org.apache.kafka.connect.transforms.Flatten$Value"
    "transforms.Flatten.delimiter"          = "_"

    "transforms.RenameFields.type"          = "org.apache.kafka.connect.transforms.ReplaceField$Value"
    "transforms.RenameFields.renames"       = "properties_@id:url,properties_@type:wxObjectType,properties_id:id,properties_type:zoneType,properties_name:name,properties_effectiveDate:effectiveDate,properties_expirationDate:expirationDate,properties_state:state,properties_cwa:cwas,properties_forecastOffices:forecastOffices,properties_timeZone:timeZones,properties_observationStations:observationStations,properties_radarStation:radarStation"

    "transforms.DropUnusedFlattenedFields.type"      = "org.apache.kafka.connect.transforms.ReplaceField$Value"
    "transforms.DropUnusedFlattenedFields.exclude"   = "observationStations"

    "transforms.MakeEventKey.type"          = "org.apache.kafka.connect.transforms.ValueToKey"
    "transforms.MakeEventKey.fields"        = "id"
  }

  depends_on = [
    confluent_kafka_topic.noaa_zones_inbound
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# Flink Statement to transform target topic from connector
# resource "confluent_flink_statement" "create_noaa_zones" {
#   organization {
#     id = local.confluent_env.org_id
#   }
#   environment {
#     id = local.confluent_env.id
#   }
#   compute_pool {
#     id = local.flink_weather_compute.id
#   }
#   principal {
#     id = local.flink_developer.svc_acct_id
#   }
#   statement     = file("./flink-sql/zones/00__create_noaa_zones.sql")
#   properties = {
#     "sql.current-catalog"  = local.confluent_env.display_name
#     "sql.current-database" = local.kafka.cluster_name
#   }
#   rest_endpoint = local.flink_weather_compute.rest_endpoint
#   credentials {
#     key    = local.sa_kafka_cluster_mgr.api_key_id
#     secret = local.sa_kafka_cluster_mgr.api_key_secret
#   }
#
#   depends_on = [
#     confluent_kafka_topic.noaa_zones_inbound,
#     # confluent_connector.noaa_zones_source
#   ]
#
#   lifecycle {
#     prevent_destroy = false
#   }
# }