package com.formypet.notification;

import com.formypet.auth.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import java.time.LocalDateTime;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class ReminderCommitTest {
    @Test
    void onlyNewCommittedReminderCanDispatch() {
        var jdbc = mock(JdbcTemplate.class);
        var dispatcher = mock(ReminderPushDispatcher.class);
        var service = new NotificationService(jdbc, mock(UserRepository.class), dispatcher, mock(com.formypet.auth.SessionGuard.class));
        when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1);
        when(jdbc.query(anyString(), org.mockito.ArgumentMatchers.<org.springframework.jdbc.core.RowMapper<Boolean>>any(), eq(1L))).thenReturn(java.util.List.of(true));
        var scheduled = LocalDateTime.of(2026, 9, 17, 12, 0);
        TransactionSynchronizationManager.initSynchronization();
        try {
            service.createReminder(1L, NotificationType.ROUTINE_REMINDER, "ROUTINE", 2L, scheduled, "title", "body");
            verifyNoInteractions(dispatcher);
            var synchronizations = TransactionSynchronizationManager.getSynchronizations();
            synchronizations.forEach(TransactionSynchronization::afterCommit);
            verify(dispatcher).dispatch(1L, NotificationType.ROUTINE_REMINDER, 2L, scheduled, "title", "body");
        } finally { TransactionSynchronizationManager.clearSynchronization(); }
    }

    @Test
    void rollbackAndDuplicateDoNotDispatch() {
        var jdbc = mock(JdbcTemplate.class);
        var dispatcher = mock(ReminderPushDispatcher.class);
        var service = new NotificationService(jdbc, mock(UserRepository.class), dispatcher, mock(com.formypet.auth.SessionGuard.class));
        when(jdbc.update(anyString(), any(Object[].class))).thenReturn(1, 0);
        when(jdbc.query(anyString(), org.mockito.ArgumentMatchers.<org.springframework.jdbc.core.RowMapper<Boolean>>any(), eq(1L))).thenReturn(java.util.List.of(true));
        TransactionSynchronizationManager.initSynchronization();
        try {
            service.createReminder(1L, NotificationType.ROUTINE_REMINDER, "ROUTINE", 2L, LocalDateTime.now(), "title", "body");
            TransactionSynchronizationManager.getSynchronizations().forEach(s -> s.afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK));
            verifyNoInteractions(dispatcher);
        } finally { TransactionSynchronizationManager.clearSynchronization(); }
        service.createReminder(1L, NotificationType.ROUTINE_REMINDER, "ROUTINE", 2L, LocalDateTime.now(), "title", "body");
        verifyNoInteractions(dispatcher);
    }
}
