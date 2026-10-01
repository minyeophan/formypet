package com.formypet.notification;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.config.NotificationProperties;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import java.sql.ResultSet;
import java.time.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class RoutineReminderWindowTest {
    @SuppressWarnings("unchecked")
    private RoutineReminderService service(ResultSet row, NotificationService notifications) {
        var jdbc = mock(JdbcTemplate.class);
        when(jdbc.query(anyString(), any(RowMapper.class))).thenAnswer(call -> {
            ((RowMapper<Object>) call.getArgument(1)).mapRow(row, 0);
            return java.util.Collections.singletonList(null);
        });
        return new RoutineReminderService(jdbc, notifications, new ObjectMapper(),
            new NotificationProperties(true, ZoneId.of("Asia/Seoul"), 60000, 5));
    }

    private ResultSet row(String times) throws Exception {
        var row = mock(ResultSet.class);
        when(row.getLong("id")).thenReturn(2L);
        when(row.getLong("user_id")).thenReturn(1L);
        when(row.getString("repeat_type")).thenReturn("daily");
        when(row.getString("days")).thenReturn("[]");
        when(row.getString("times")).thenReturn(times);
        when(row.getObject("start_date", LocalDate.class)).thenReturn(LocalDate.of(2026, 9, 1));
        return row;
    }

    @Test
    void midnightWindowIncludesPreviousDateEvenWhenRoutineEndedYesterday() throws Exception {
        var notifications = mock(NotificationService.class);
        var row = row("[\"23:59\"]");
        when(row.getObject("end_date", LocalDate.class)).thenReturn(LocalDate.of(2026, 9, 17));
        service(row, notifications).createDueNotifications(LocalDateTime.of(2026, 9, 18, 0, 2));
        verify(notifications).createReminder(eq(1L), eq(NotificationType.ROUTINE_REMINDER), eq("ROUTINE"), eq(2L),
            eq(LocalDateTime.of(2026, 9, 17, 23, 59)), anyString(), anyString());
    }

    @Test
    void malformedTimeDoesNotStopValidTimeAndFiveMinuteBoundaryIsInclusive() throws Exception {
        var notifications = mock(NotificationService.class);
        var row = row("[\"bad\",\"11:54\",\"11:55\",\"12:01\"]");
        service(row, notifications).createDueNotifications(LocalDateTime.of(2026, 9, 18, 12, 0));
        verify(notifications).createReminder(eq(1L), eq(NotificationType.ROUTINE_REMINDER), eq("ROUTINE"), eq(2L),
            eq(LocalDateTime.of(2026, 9, 18, 11, 55)), anyString(), anyString());
        verifyNoMoreInteractions(notifications);
    }

    @Test
    void dateBeforeStartAndZeroMonthlyIntervalAreSkipped() throws Exception {
        var notifications = mock(NotificationService.class);
        var row = row("[\"23:59\"]");
        when(row.getObject("start_date", LocalDate.class)).thenReturn(LocalDate.of(2026, 9, 18));
        service(row, notifications).createDueNotifications(LocalDateTime.of(2026, 9, 18, 0, 2));
        when(row.getString("repeat_type")).thenReturn("monthly");
        service(row, notifications).createDueNotifications(LocalDateTime.of(2026, 9, 18, 23, 59));
        verifyNoInteractions(notifications);
    }
}
