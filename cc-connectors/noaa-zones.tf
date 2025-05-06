# resource "confluent_connector" "noaa_zones_source" {
#   environment {
#     id = local.confluent_env_id
#   }
#   kafka_cluster {
#     id = local.kafka_cluster_id
#   }
#
#   config_sensitive = {}
#
#   config_nonsensitive = {
#     "connector.class"          = "HttpSource"
#     "name"                     = "http_src_noaa_zones"
#     "kafka.auth.mode"          = "KAFKA_API_KEY"
#     "kafka.api.key"            = local.kafka_app_manager_api_key
#     "kafka.api.secret"         = local.kafka_app_manager_api_secret
#     "kafka.topic"              = confluent_kafka_topic.noaa_zones_inbound.topic_name
#     "output.data.format"       = "AVRO"
#     "tasks.max"                = "1"
#     "topic.name.pattern"       = confluent_kafka_topic.noaa_zones_inbound.topic_name
#     "url"                      = "https://api.weather.gov/zones"
#     "http.offset.mode"         = "SIMPLE_INCREMENTING"
#     "http.initial.offset"      = "0"
#     "http.response.data.json.pointer" = "/features"
#     "request.interval.ms"      = 600000
#
#     "transforms"                            = "DropUnusedFields,Flatten,RenameFields,DropUnusedFlattenedFields,MakeEventKey"
#     "transforms.DropUnusedFields.type"      = "org.apache.kafka.connect.transforms.ReplaceField$Value"
#     "transforms.DropUnusedFields.exclude"   = "id,type"
#
#     "transforms.Flatten.type"               = "org.apache.kafka.connect.transforms.Flatten$Value"
#     "transforms.Flatten.delimiter"          = "_"
#
#     "transforms.RenameFields.type"          = "org.apache.kafka.connect.transforms.ReplaceField$Value"
#     "transforms.RenameFields.renames"       = "properties_@id:url,properties_@type:wxObjectType,properties_id:id,properties_type:zoneType,properties_name:name,properties_effectiveDate:effectiveDate,properties_expirationDate:expirationDate,properties_state:state,properties_cwa:cwas,properties_forecastOffices:forecastOffices,properties_timeZone:timeZones,properties_observationStations:observationStations,properties_radarStation:radarStation"
#
#     "transforms.DropUnusedFlattenedFields.type"      = "org.apache.kafka.connect.transforms.ReplaceField$Value"
#     "transforms.DropUnusedFlattenedFields.exclude"   = "observationStations"
#
#     "transforms.MakeEventKey.type"          = "org.apache.kafka.connect.transforms.ValueToKey"
#     "transforms.MakeEventKey.fields"        = "id"
#   }
#
#   depends_on = [
#     confluent_kafka_topic.noaa_zones_inbound
#   ]
#
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
# resource "confluent_flink_statement" "create_ws_zones" {
#   organization {
#     id = local.confluent_org_id
#   }
#   environment {
#     id = local.confluent_env_id
#   }
#   compute_pool {
#     id = local.flink_weather_compute_id
#   }
#   principal {
#     id = local.flink_stmt_runner_id
#   }
#   statement     = file("./flink-sql/zones/00__create_ws_zones.sql")
#   properties = {
#     "sql.current-catalog"  = local.confluent_env_name
#     "sql.current-database" = local.kafka_cluster_name
#   }
#   rest_endpoint = local.flink_weather_region_rest_endpoint
#   credentials {
#     key    = local.flink_api_key
#     secret = local.flink_api_secret
#   }
#
#   depends_on = [
#     confluent_kafka_topic.noaa_zones_inbound,
#     confluent_connector.noaa_zones_source
#   ]
#
#   lifecycle {
#     prevent_destroy = false
#   }
# }