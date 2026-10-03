package com.formypet.common.time;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

/** The boundary between an event instant and MySQL DATETIME columns containing UTC. */
public final class UtcTime {
    private UtcTime() {}

    public static LocalDateTime toDatabase(Instant instant) {
        return instant == null ? null : LocalDateTime.ofInstant(instant, ZoneOffset.UTC);
    }

    public static Instant fromDatabase(Object value) {
        if (value == null) return null;
        if (value instanceof Instant instant) return instant;
        if (value instanceof LocalDateTime time) return time.toInstant(ZoneOffset.UTC);
        // A JDBC DATETIME timestamp represents wall-clock fields, not a zone-aware instant.
        if (value instanceof Timestamp time) return time.toLocalDateTime().toInstant(ZoneOffset.UTC);
        throw new IllegalArgumentException("Unsupported UTC DATETIME representation: " + value.getClass().getSimpleName());
    }
}
