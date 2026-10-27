package talks.sandonjacobs.ali;

import java.util.Map;
import java.util.Properties;
import java.util.Random;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;

/** Ali's demo microservice: sends synthetic app events until interrupted (Ctrl-C). */
public final class Main {

  private Main() {}

  public static void main(String[] args) throws Exception {
    Map<String, String> env = System.getenv();
    ProducerConfigLoader.requireAll(env);

    String topic = ProducerConfigLoader.topic(env);
    long intervalMs = Long.parseLong(env.getOrDefault("APP_EVENTS_INTERVAL_MS", "1000"));

    EventGenerator generator = new EventGenerator(new Random());
    Properties props = ProducerConfigLoader.producerProperties(env);

    try (KafkaProducer<String, AppEvent> producer = new KafkaProducer<>(props)) {
      Runtime.getRuntime().addShutdownHook(new Thread(producer::close));
      System.out.println("Producing to " + topic + " every " + intervalMs + " ms. Ctrl-C to stop.");

      long sent = 0;
      while (!Thread.currentThread().isInterrupted()) {
        AppEvent event = generator.next();
        String key = event.getEventType().name();
        producer.send(
            new ProducerRecord<>(topic, key, event),
            (metadata, error) -> {
              if (error != null) {
                System.err.println("Send failed: " + error.getMessage());
              }
            });
        sent++;
        if (sent % 10 == 0) {
          System.out.println("Sent " + sent + " events");
        }
        Thread.sleep(intervalMs);
      }
    }
  }
}
