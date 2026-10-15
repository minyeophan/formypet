package com.formypet.domain.record.entity;

import com.formypet.common.exception.InvalidInputException;
import com.formypet.common.time.UtcTime;
import org.junit.jupiter.api.Test;
import java.time.*;
import java.util.List;
import static org.assertj.core.api.Assertions.*;

class ActivityRecordTest {
    @Test
    void omittedFieldsPreserveValuesAndEmptyNoteClears() {
        var date = LocalDate.of(2026, 10, 15);
        var time = LocalTime.of(23, 10, 15);
        var record = ActivityRecord.create(1L, "water", date, time, 2L, " note ");
        record.update(null, null, null, null);
        assertThat(record.getDate()).isEqualTo(date);
        assertThat(record.getTime()).isEqualTo(time);
        assertThat(record.getRoutineId()).isEqualTo(2L);
        assertThat(record.getNote()).isEqualTo(" note ");
        record.update(date.plusDays(1), LocalTime.of(9, 5), 3L, "");
        assertThat(record.getDate()).isEqualTo(date.plusDays(1));
        assertThat(record.getTime()).isEqualTo(LocalTime.of(9, 5));
        assertThat(record.getRoutineId()).isEqualTo(3L);
        assertThat(record.getNote()).isEmpty();
        assertThat(record.getTypeId()).isEqualTo("water");
    }

    @Test
    void supportsExactlyExistingTypes() {
        for (var type : List.of("meal", "water", "medicine", "poop", "walk", "weight", "vet", "diary", "etc")) {
            assertThatCode(() -> ActivityRecord.validateType(type)).doesNotThrowAnyException();
        }
        for (var type : List.of("sleep", "play", "checkup", "WATER", " water ", "")) {
            assertThatThrownBy(() -> ActivityRecord.validateType(type)).isInstanceOf(InvalidInputException.class);
        }
    }

    @Test
    void timestampsUseUtcAndCreatedAtDoesNotChangeOnUpdate() {
        var before = UtcTime.toDatabase(Instant.now());
        var record = ActivityRecord.create(1L, "diary", LocalDate.now(), null, null, null);
        var created = record.getCreatedAt();
        assertThat(created).isBetween(before, UtcTime.toDatabase(Instant.now()));
        assertThat(record.getUpdatedAt()).isEqualTo(created);
        record.update(null, null, null, "new");
        assertThat(record.getCreatedAt()).isEqualTo(created);
        assertThat(record.getUpdatedAt()).isAfterOrEqualTo(created);
    }
}
