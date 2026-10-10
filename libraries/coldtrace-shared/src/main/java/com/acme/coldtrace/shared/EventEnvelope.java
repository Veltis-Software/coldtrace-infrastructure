package com.acme.coldtrace.shared;

import java.time.Instant;
import java.util.UUID;

public record EventEnvelope(
    UUID eventId,
    String eventType,
    int version,
    Instant occurredAt,
    long organizationId,
    String correlationId,
    String producer,
    Object payload) {
  public static EventEnvelope create(
      String type, Instant now, long organizationId, String correlationId, Object payload) {
    return new EventEnvelope(
        UUID.randomUUID(),
        type,
        1,
        now,
        organizationId,
        correlationId,
        "monitoring-service",
        payload);
  }
}
