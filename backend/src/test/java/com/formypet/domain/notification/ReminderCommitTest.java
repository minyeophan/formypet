package com.formypet.domain.notification;

import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.repository.NotificationRepository;
import com.formypet.domain.notification.repository.jdbc.NotificationCommands;
import com.formypet.domain.notification.service.ReminderPushDispatcher;
import com.formypet.domain.notification.service.impl.NotificationReminderServiceImpl;
import java.time.LocalDateTime;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ReminderCommitTest {
    @Test
    void onlyNewCommittedReminderCanDispatch() {
        var commands = mock(NotificationCommands.class);
        var dispatcher = mock(ReminderPushDispatcher.class);
        var service = new NotificationReminderServiceImpl(mock(NotificationRepository.class), commands, dispatcher, new com.formypet.domain.notification.config.NotificationProperties(true, java.time.ZoneId.of("Asia/Seoul"), 60000, 5));
        when(commands.insertReminder(anyLong(), anyString(), anyString(), anyLong(), any(), anyString(), anyString(), any())).thenReturn(1);
        when(commands.lockReminderPreference(1L)).thenReturn(true);
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
        var commands = mock(NotificationCommands.class);
        var dispatcher = mock(ReminderPushDispatcher.class);
        var service = new NotificationReminderServiceImpl(mock(NotificationRepository.class), commands, dispatcher, new com.formypet.domain.notification.config.NotificationProperties(true, java.time.ZoneId.of("Asia/Seoul"), 60000, 5));
        when(commands.insertReminder(anyLong(), anyString(), anyString(), anyLong(), any(), anyString(), anyString(), any())).thenReturn(1, 0);
        when(commands.lockReminderPreference(1L)).thenReturn(true);
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
