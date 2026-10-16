package com.formypet.domain.routine.entity;

import com.formypet.global.exception.InvalidInputException;
import org.junit.jupiter.api.Test;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import static org.assertj.core.api.Assertions.*;

class RoutineTest {
    private Routine routine(String repeat, List<Integer> days, int interval, LocalDate start) {
        return Routine.create(1L, "label", "meal", repeat, days, interval, start, null,
                List.of("09:00", "18:00"), "note", Map.of("startLat", 1, "amount", 2), false);
    }

    @Test
    void biweeklyUsesWholeWeeksFromStartAndSundayIsZero() {
        var start = LocalDate.of(2026, 10, 14);
        var r = routine("biweekly", List.of(0), 1, start);
        assertThat(r.isScheduledOn(start.minusDays(3))).isFalse();
        assertThat(r.isScheduledOn(start.plusDays(4))).isTrue();
        assertThat(r.isScheduledOn(start.plusDays(11))).isFalse();
        assertThat(r.isScheduledOn(start.plusDays(18))).isTrue();
    }

    @Test
    void monthlyDoesNotClampMissingMonthDays() {
        var r = routine("monthly", List.of(), 2, LocalDate.of(2026, 1, 31));
        assertThat(r.isScheduledOn(LocalDate.of(2026, 2, 28))).isFalse();
        assertThat(r.isScheduledOn(LocalDate.of(2026, 3, 31))).isTrue();
        assertThat(r.isScheduledOn(LocalDate.of(2026, 4, 30))).isFalse();
    }

    @Test
    void partialUpdatePreservesOmittedValuesAndExplicitClearWins() {
        var start = LocalDate.of(2026, 10, 14);
        var r = routine("daily", List.of(), 1, start);
        r.update(null, null, null, null, null, null, start.plusDays(1), null, null, null, null, null, false);
        assertThat(r.isScheduledOn(start.plusDays(1))).isTrue();
        assertThat(r.isScheduledOn(start.plusDays(2))).isFalse();
        r.update("new", null, null, null, null, null, start, null, "", null, null, null, true);
        assertThat(r.getEndDate()).isNull();
        assertThat(r.getTimes()).containsExactly("09:00", "18:00");
        assertThat(r.getNote()).isEmpty();
        assertThat(r.getDetail()).containsEntry("amount", 2).doesNotContainKey("startLat");
        r.update(null, null, null, null, null, null, null, null, null, null, false, null, false);
        assertThat(r.isScheduledOn(start)).isFalse();
    }

    @Test
    void rejectsInvalidRulesAndCountsLabelCodePoints() {
        assertThatThrownBy(() -> routine("weekly", List.of(), 1, LocalDate.now()))
                .isInstanceOf(InvalidInputException.class);
        assertThatThrownBy(() -> routine("monthly", List.of(), 0, LocalDate.now()))
                .isInstanceOf(InvalidInputException.class);
        assertThatCode(() -> Routine.validateLabel("🐾".repeat(30))).doesNotThrowAnyException();
        assertThatThrownBy(() -> Routine.validateLabel("🐾".repeat(31)))
                .isInstanceOf(InvalidInputException.class);
    }
}
