package talks.sandonjacobs.ali;

import io.confluent.kafka.serializers.KafkaAvroSerializer;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.StringSerializer;

/** Builds producer settings from the values the personas published to .env. */
public final class ProducerConfigLoader {

  static final String BOOTSTRAP = "OMAR_KAFKA_BOOTSTRAP_ENDPOINT";
  static final String KAFKA_KEY = "OMAR_ALI_KAFKA_API_KEY";
  static final String KAFKA_SECRET = "OMAR_ALI_KAFKA_API_SECRET";
  static final String SR_URL = "OMAR_SCHEMA_REGISTRY_REST_ENDPOINT";
  static final String SR_KEY = "OMAR_ALI_SCHEMA_REGISTRY_API_KEY";
  static final String SR_SECRET = "OMAR_ALI_SCHEMA_REGISTRY_API_SECRET";
  static final String TOPIC = "ALI_EVENTS_TOPIC";

  private static final List<String> REQUIRED =
      List.of(BOOTSTRAP, KAFKA_KEY, KAFKA_SECRET, SR_URL, SR_KEY, SR_SECRET, TOPIC);

  private ProducerConfigLoader() {}

  /** Fails naming every missing variable, never printing values. */
  public static void requireAll(Map<String, String> env) {
    List<String> missing = new ArrayList<>();
    for (String name : REQUIRED) {
      String value = env.get(name);
      if (value == null || value.isBlank()) {
        missing.add(name);
      }
    }
    if (!missing.isEmpty()) {
      throw new IllegalStateException(
          "Missing required environment variables: "
              + String.join(", ", missing)
              + ". Apply Omar, Ida, Ali, and Dan first, then run 'make ali-run'.");
    }
  }

  public static String topic(Map<String, String> env) {
    requireAll(env);
    return env.get(TOPIC);
  }

  public static Properties producerProperties(Map<String, String> env) {
    requireAll(env);
    Properties props = new Properties();

    // Terraform publishes the bootstrap endpoint as SASL_SSL://host:port; the client wants host:port.
    String bootstrap = env.get(BOOTSTRAP).replaceFirst("^[A-Za-z_]+://", "");
    props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrap);
    props.put("security.protocol", "SASL_SSL");
    props.put("sasl.mechanism", "PLAIN");
    props.put(
        "sasl.jaas.config",
        "org.apache.kafka.common.security.plain.PlainLoginModule required username=\""
            + env.get(KAFKA_KEY)
            + "\" password=\""
            + env.get(KAFKA_SECRET)
            + "\";");
    props.put("client.dns.lookup", "use_all_dns_ips");
    props.put(ProducerConfig.ACKS_CONFIG, "all");
    props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
    props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class.getName());

    props.put("schema.registry.url", env.get(SR_URL));
    props.put("basic.auth.credentials.source", "USER_INFO");
    props.put("basic.auth.user.info", env.get(SR_KEY) + ":" + env.get(SR_SECRET));
    // Dan owns the schema; the producer must use it as registered and never add its own.
    props.put("auto.register.schemas", "false");
    props.put("use.latest.version", "true");
    return props;
  }
}
