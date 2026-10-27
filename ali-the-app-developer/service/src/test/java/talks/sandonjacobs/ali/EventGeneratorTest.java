package talks.sandonjacobs.ali;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.HashSet;
import java.util.Random;
import java.util.Set;
import org.apache.avro.io.BinaryEncoder;
import org.apache.avro.io.DecoderFactory;
import org.apache.avro.io.EncoderFactory;
import org.apache.avro.specific.SpecificDatumReader;
import org.apache.avro.specific.SpecificDatumWriter;
import org.junit.jupiter.api.Test;

/** AppEvent is generated from Dan's schema, so these tests run against the real contract. */
class EventGeneratorTest {

  @Test
  void generatedEventsSerializeAgainstDansSchema() throws IOException {
    EventGenerator generator = new EventGenerator(new Random(42));
    for (int i = 0; i < 200; i++) {
      AppEvent event = generator.next();
      ByteArrayOutputStream out = new ByteArrayOutputStream();
      BinaryEncoder encoder = EncoderFactory.get().binaryEncoder(out, null);
      new SpecificDatumWriter<>(AppEvent.class).write(event, encoder);
      encoder.flush();
      AppEvent decoded =
          new SpecificDatumReader<>(AppEvent.class)
              .read(null, DecoderFactory.get().binaryDecoder(out.toByteArray(), null));
      assertEquals(event.getEventId(), decoded.getEventId());
    }
  }

  @Test
  void eventIdsAreUnique() {
    EventGenerator generator = new EventGenerator(new Random(7));
    assertNotEquals(generator.next().getEventId(), generator.next().getEventId());
  }

  @Test
  void allEventTypesAreProduced() {
    EventGenerator generator = new EventGenerator(new Random(3));
    Set<EventType> seen = new HashSet<>();
    for (int i = 0; i < 100; i++) {
      seen.add(generator.next().getEventType());
    }
    assertEquals(Set.of(EventType.CREATED, EventType.UPDATED, EventType.DELETED), seen);
  }
}
