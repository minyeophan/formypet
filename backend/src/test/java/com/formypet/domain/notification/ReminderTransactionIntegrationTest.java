package com.formypet.domain.notification;

import com.formypet.domain.notification.client.PushSender;
import com.formypet.domain.notification.client.PushSendResult;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.service.NotificationService;
import com.formypet.support.IntegrationTestSupport;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class ReminderTransactionIntegrationTest extends IntegrationTestSupport {
    @Autowired NotificationService notifications;
    @Autowired JdbcTemplate jdbc;
    @Autowired TransactionTemplate transactions;
    @MockitoBean PushSender sender;
    long user, routine;
    String token;
    final LocalDateTime due = LocalDateTime.of(2026, 9, 18, 9, 0);

    @BeforeEach void seed() {
        token = "transaction-" + UUID.randomUUID();
        String email = token + "@test.invalid";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'test','test')", email);
        user = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        jdbc.update("INSERT INTO pets(user_id,name,species,accent_color,bg_light) VALUES (?,'pet','dog','#000000','#ffffff')", user);
        long pet = jdbc.queryForObject("SELECT id FROM pets WHERE user_id=?", Long.class, user);
        jdbc.update("""
                INSERT INTO routines(pet_id,label,type_id,repeat_type,days,monthly_interval,start_date,times,notification_enabled)
                VALUES (?,'label','water','daily','[]',1,'2026-09-18','["09:00"]',TRUE)
                """, pet);
        routine = jdbc.queryForObject("SELECT id FROM routines WHERE pet_id=?", Long.class, pet);
        jdbc.update("INSERT INTO device_tokens(user_id,token,platform) VALUES (?,?,'ANDROID')", user, token);
    }

    @AfterEach void cleanup() { jdbc.update("DELETE FROM users WHERE id=?", user); }

    @Test void commitDispatchesOnceAndInvalidationCommitsInTheNewTransaction() {
        when(sender.send(any(), any(), any(), any(), any())).thenAnswer(call -> {
            assertThat(count()).isEqualTo(1); // dispatcher REQUIRES_NEW can see the committed row
            return new PushSendResult(0, 1, List.of(token));
        });
        transactions.executeWithoutResult(status -> {
            create();
            verifyNoInteractions(sender);
            assertThat(count()).isEqualTo(1);
        });
        verify(sender).send("ROUTINE_REMINDER", routine, "title", "body", List.of(token));
        assertThat(jdbc.queryForObject("SELECT enabled FROM device_tokens WHERE token=?", Boolean.class, token)).isFalse();
        transactions.executeWithoutResult(status -> create());
        verifyNoMoreInteractions(sender);
        assertThat(count()).isEqualTo(1);
    }

    @Test void rollbackRemovesNotificationAndNeverDispatches() {
        transactions.executeWithoutResult(status -> {
            create();
            assertThat(count()).isEqualTo(1);
            status.setRollbackOnly();
        });
        verifyNoInteractions(sender);
        assertThat(count()).isZero();
        assertThat(jdbc.queryForObject("SELECT enabled FROM device_tokens WHERE token=?", Boolean.class, token)).isTrue();
    }

    private void create() {
        notifications.createReminder(user, NotificationType.ROUTINE_REMINDER, "ROUTINE", routine, due, "title", "body");
    }
    private int count() {
        return jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE recipient_user_id=?", Integer.class, user);
    }
}
