package talks.sandonjacobs.ali;

import java.time.Instant;
import java.util.List;
import java.util.Random;
import java.util.UUID;

/**
 * Produces synthetic application events. {@link AppEvent} is generated at build time from the
 * schema Dan registered, so a schema change shows up here as a compile error. The use case behind
 * these events is still to be decided.
 */
public final class EventGenerator {

  private static final List<EventType> EVENT_TYPES =
      List.of(EventType.CREATED, EventType.UPDATED, EventType.DELETED);

  private final Random random;

  public EventGenerator(Random random) {
    this.random = random;
  }

  public AppEvent next() {
    return AppEvent.newBuilder()
        .setEventId(UUID.randomUUID().toString())
        .setEventTime(Instant.now())
        .setEventType(EVENT_TYPES.get(random.nextInt(EVENT_TYPES.size())))
        .build();
  }
}
