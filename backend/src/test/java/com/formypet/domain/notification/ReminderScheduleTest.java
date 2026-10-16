package com.formypet.domain.notification;

import com.formypet.domain.notification.entity.ReminderSchedule;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class ReminderScheduleTest {
    @Test void recurrenceKeepsWeekOriginSundayIndexAndCalendarMonthSemantics() {
        var start = LocalDate.of(2026, 9, 1);
        assertThat(ReminderSchedule.scheduledOn("daily", start, start, List.of(), 1)).isTrue();
        assertThat(ReminderSchedule.scheduledOn("weekly", start, LocalDate.of(2026, 9, 6), List.of(0), 1)).isTrue();
        assertThat(ReminderSchedule.scheduledOn("biweekly", start, start.plusWeeks(1), List.of(2), 1)).isFalse();
        assertThat(ReminderSchedule.scheduledOn("biweekly", start, start.plusWeeks(2), List.of(2), 1)).isTrue();
        assertThat(ReminderSchedule.scheduledOn("monthly", start, start.plusMonths(1), List.of(), 2)).isFalse();
        assertThat(ReminderSchedule.scheduledOn("monthly", start, start.plusMonths(2), List.of(), 2)).isTrue();
        assertThat(ReminderSchedule.scheduledOn("monthly", LocalDate.of(2026, 3, 31), LocalDate.of(2026, 4, 30), List.of(), 1)).isFalse();
        assertThat(ReminderSchedule.scheduledOn("unknown", start, start, List.of(), 1)).isFalse();
    }

    @Test void careReminderOffsetsKeepKoreanEnglishWhitespaceAndDisabledValues() {
        assertThat(ReminderSchedule.reminderOffset(" 하루 전 ")).isEqualTo(1440L);
        assertThat(ReminderSchedule.reminderOffset("1 DAY BEFORE")).isEqualTo(1440L);
        assertThat(ReminderSchedule.reminderOffset("2시간 전")).isEqualTo(120L);
        assertThat(ReminderSchedule.reminderOffset("2 hours before")).isEqualTo(120L);
        assertThat(ReminderSchedule.reminderOffset("1시간 전")).isEqualTo(60L);
        assertThat(ReminderSchedule.reminderOffset("1 hour before")).isEqualTo(60L);
        assertThat(ReminderSchedule.reminderOffset("30분 전")).isEqualTo(30L);
        assertThat(ReminderSchedule.reminderOffset("30 minutes before")).isEqualTo(30L);
        assertThat(ReminderSchedule.reminderOffset("none")).isNull();
        assertThat(ReminderSchedule.reminderOffset(null)).isNull();
    }
}
