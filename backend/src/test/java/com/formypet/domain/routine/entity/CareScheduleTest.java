package com.formypet.domain.routine.entity;

import com.formypet.global.exception.InvalidInputException;
import org.junit.jupiter.api.Test;
import java.time.LocalDate;
import java.time.LocalTime;
import static org.assertj.core.api.Assertions.*;

class CareScheduleTest {
    private final LocalDate date = LocalDate.of(2026, 10, 15);

    @Test
    void allDayClearsTimesAndNormalizesText() {
        var schedule = CareSchedule.create(1L, " hospital ", " Checkup ", date,
                LocalTime.of(9, 5), date, LocalTime.of(10, 30), true, "  ", " memo ", " none ");
        assertThat(schedule.getStartTime()).isNull();
        assertThat(schedule.getEndTime()).isNull();
        assertThat(schedule.getCategoryId()).isEqualTo("hospital");
        assertThat(schedule.getTitle()).isEqualTo("Checkup");
        assertThat(schedule.getPlace()).isNull();
        assertThat(schedule.getMemo()).isEqualTo("memo");
        assertThat(schedule.getReminder()).isEqualTo("none");
    }

    @Test
    void timedSchedulePreservesWallClockAndExistingSameDayOrderContract() {
        var schedule = CareSchedule.create(1L, "etc", "title", date,
                LocalTime.of(23, 10), date, LocalTime.of(1, 0), false, "\u2003", null, "none");
        assertThat(schedule.getStartTime()).isEqualTo(LocalTime.of(23, 10));
        assertThat(schedule.getEndTime()).isEqualTo(LocalTime.of(1, 0));
        assertThat(schedule.getPlace()).isEqualTo("\u2003");
        schedule.update("etc", "new", date, null, date, null, false, null, null, "none");
        assertThat(schedule.getStartTime()).isNull();
        assertThat(schedule.getPlace()).isNull();
    }

    @Test
    void rejectsBackwardsDatesAndBlankTitle() {
        assertThatThrownBy(() -> CareSchedule.create(1L, "etc", "title", date, null,
                date.minusDays(1), null, false, null, null, "none"))
                .isInstanceOf(InvalidInputException.class).hasMessage("Invalid date range.");
        assertThatThrownBy(() -> CareSchedule.create(1L, "etc", " ", date, null,
                date, null, false, null, null, "none"))
                .isInstanceOf(InvalidInputException.class);
    }
}
