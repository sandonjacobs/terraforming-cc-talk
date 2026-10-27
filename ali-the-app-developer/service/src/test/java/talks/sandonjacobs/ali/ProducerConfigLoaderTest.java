package talks.sandonjacobs.ali;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import org.junit.jupiter.api.Test;

class ProducerConfigLoaderTest {

  private static Map<String, String> fullEnv() {
    Map<String, String> env = new HashMap<>();
    env.put(ProducerConfigLoader.BOOTSTRAP, "SASL_SSL://pkc-mock.us-east-1.aws.confluent.cloud:9092");
    env.put(ProducerConfigLoader.KAFKA_KEY, "kafka-key");
    env.put(ProducerConfigLoader.KAFKA_SECRET, "kafka-secret");
    env.put(ProducerConfigLoader.SR_URL, "https://psrc-mock.us-east-1.aws.confluent.cloud");
    env.put(ProducerConfigLoader.SR_KEY, "sr-key");
    env.put(ProducerConfigLoader.SR_SECRET, "sr-secret");
    env.put(ProducerConfigLoader.TOPIC, "app-events");
    return env;
  }

  @Test
  void failsNamingEveryMissingVariable() {
    Map<String, String> env = fullEnv();
    env.remove(ProducerConfigLoader.KAFKA_KEY);
    env.put(ProducerConfigLoader.SR_SECRET, " ");

    IllegalStateException error =
        assertThrows(IllegalStateException.class, () -> ProducerConfigLoader.requireAll(env));

    assertTrue(error.getMessage().contains(ProducerConfigLoader.KAFKA_KEY));
    assertTrue(error.getMessage().contains(ProducerConfigLoader.SR_SECRET));
    assertFalse(error.getMessage().contains("kafka-secret"), "message must not leak secret values");
  }

  @Test
  void stripsTheProtocolFromTheBootstrapEndpoint() {
    Properties props = ProducerConfigLoader.producerProperties(fullEnv());
    assertEquals("pkc-mock.us-east-1.aws.confluent.cloud:9092", props.get("bootstrap.servers"));
  }

  @Test
  void neverRegistersSchemasAndUsesTheLatestOne() {
    Properties props = ProducerConfigLoader.producerProperties(fullEnv());
    assertEquals("false", props.get("auto.register.schemas"));
    assertEquals("true", props.get("use.latest.version"));
  }

  @Test
  void usesAlisCredentialsForKafkaAndSchemaRegistry() {
    Properties props = ProducerConfigLoader.producerProperties(fullEnv());
    assertTrue(props.get("sasl.jaas.config").toString().contains("kafka-key"));
    assertEquals("sr-key:sr-secret", props.get("basic.auth.user.info"));
  }

  @Test
  void readsTheTopicFromTheEnvironment() {
    assertEquals("app-events", ProducerConfigLoader.topic(fullEnv()));
  }
}
