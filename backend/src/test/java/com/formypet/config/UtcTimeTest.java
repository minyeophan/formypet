package com.formypet.config;

import com.formypet.common.time.UtcTime;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.TimeZone;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.assertj.core.api.Assertions.assertThat;

class UtcTimeTest {
    @ParameterizedTest
    @ValueSource(strings = {"UTC", "Asia/Seoul", "America/Los_Angeles"})
    void datetimeBoundaryKeepsUtcFieldsAndMicroseconds(String zone) {
        var original = TimeZone.getDefault();
        try {
            TimeZone.setDefault(TimeZone.getTimeZone(zone));
            var instant = Instant.parse("2026-10-03T15:54:32.123456Z");
            var stored = LocalDateTime.parse("2026-10-03T15:54:32.123456");
            assertThat(UtcTime.toDatabase(instant)).isEqualTo(stored);
            assertThat(UtcTime.fromDatabase(stored)).isEqualTo(instant);
            assertThat(UtcTime.fromDatabase(Timestamp.valueOf(stored))).isEqualTo(instant);
            assertThat(UtcTime.fromDatabase(UtcTime.toDatabase(instant))).isEqualTo(instant);
            assertThat(UtcTime.fromDatabase(null)).isNull();
            assertThat(UtcTime.toDatabase(null)).isNull();
        } finally {
            TimeZone.setDefault(original);
        }
    }
}
