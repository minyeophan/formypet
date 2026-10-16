package com.formypet.domain.notification;

import com.formypet.domain.notification.config.NotificationProperties;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.repository.query.CareReminderCandidate;
import com.formypet.domain.notification.repository.query.ReminderCandidateRepository;
import com.formypet.domain.notification.service.NotificationService;
import com.formypet.domain.notification.service.impl.CareScheduleReminderServiceImpl;
import java.time.*;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.mockito.Mockito.*;

class CareReminderWindowTest {
    @Test void missingTimeDefaultsToNineAndWindowIncludesBothEnds() {
        var repository = mock(ReminderCandidateRepository.class);
        var notifications = mock(NotificationService.class);
        var date = LocalDate.of(2026, 9, 18);
        when(repository.careSchedules()).thenReturn(List.of(
                new CareReminderCandidate(2, 1, "first", "pet", date, null, "1시간 전"),
                new CareReminderCandidate(3, 1, "last", "pet", date, LocalTime.of(9, 5), "1 hour before"),
                new CareReminderCandidate(4, 1, "late", "pet", date, LocalTime.of(9, 6), "1시간 전"),
                new CareReminderCandidate(5, 1, "none", "pet", date, null, "알림 없음")));
        var service = new CareScheduleReminderServiceImpl(repository, notifications,
                new NotificationProperties(true, ZoneId.of("Asia/Seoul"), 60000, 5));
        service.createDueNotifications(date.atTime(8, 5));
        verify(notifications).createReminder(1L, NotificationType.CARE_SCHEDULE_REMINDER, "CARE_SCHEDULE", 2L,
                date.atTime(8, 0), "케어 일정 알림", "pet님의 일정: first");
        verify(notifications).createReminder(1L, NotificationType.CARE_SCHEDULE_REMINDER, "CARE_SCHEDULE", 3L,
                date.atTime(8, 5), "케어 일정 알림", "pet님의 일정: last");
        verifyNoMoreInteractions(notifications);
    }
}
