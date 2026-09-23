package com.formypet.notification;

import com.formypet.notification.dto.NotificationSettingsRequest;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.support.TransactionTemplate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;

class NotificationSettingsRaceIntegrationTest extends IntegrationTestSupport {
    @Autowired JdbcTemplate jdbc;
    @Autowired NotificationService service;
    @Autowired TransactionTemplate transactions;
    long userId;
    String email;

    @BeforeEach void seed() {
        email = UUID.randomUUID() + "@settings.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'test','test')", email);
        userId = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
    }
    @AfterEach void cleanup() {
        SecurityContextHolder.clearContext();
        jdbc.update("DELETE FROM users WHERE id=?", userId);
    }
    void authenticate(long version) {
        var auth = new UsernamePasswordAuthenticationToken(email, null, List.of());
        auth.setDetails(version);
        SecurityContextHolder.getContext().setAuthentication(auth);
    }
    int count() {
        return jdbc.queryForObject("SELECT COUNT(*) FROM notifications WHERE recipient_user_id=?", Integer.class, userId);
    }
    void reminder(NotificationType type) {
        service.createReminder(userId, type, type.name(), 999L, LocalDateTime.now(), "test", "test");
    }
    @Test void staleSessionCannotChangePreferenceAfterReset() {
        authenticate(0);
        jdbc.update("UPDATE users SET auth_version=1 WHERE id=?", userId);
        assertThrows(BadCredentialsException.class,
            () -> service.updateSettings(email, new NotificationSettingsRequest(false)));
        assertTrue(service.getSettings(email).enabled());
    }
    @Test void currentSessionChangesOnlyPreference() {
        authenticate(0);
        assertFalse(service.updateSettings(email, new NotificationSettingsRequest(false)).enabled());
        assertEquals(0L, jdbc.queryForObject("SELECT auth_version FROM users WHERE id=?", Long.class, userId));
    }
    @Test void disabledUserDoesNotReceiveEitherReminderType() {
        jdbc.update("UPDATE users SET notification_enabled=0 WHERE id=?", userId);
        reminder(NotificationType.ROUTINE_REMINDER);
        reminder(NotificationType.CARE_SCHEDULE_REMINDER);
        assertEquals(0, count());
    }
    @Test void disabledPreferenceKeepsExistingHistory() {
        reminder(NotificationType.ROUTINE_REMINDER);
        authenticate(0);
        service.updateSettings(email, new NotificationSettingsRequest(false));
        assertEquals(1, count());
    }
    @Test @Timeout(20) void queuedCreationRechecksPreferenceAfterUserLock() throws Exception {
        var executor = Executors.newSingleThreadExecutor();
        var started = new CountDownLatch(1);
        final Future<?>[] pending = new Future<?>[1];
        try {
            transactions.executeWithoutResult(status -> {
                jdbc.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, userId);
                pending[0] = executor.submit(() -> {
                    started.countDown();
                    reminder(NotificationType.ROUTINE_REMINDER);
                });
                try { assertTrue(started.await(5, TimeUnit.SECONDS)); }
                catch (InterruptedException e) { throw new RuntimeException(e); }
                jdbc.update("UPDATE users SET notification_enabled=0 WHERE id=?", userId);
            });
            pending[0].get(10, TimeUnit.SECONDS);
            assertEquals(0, count());
        } finally { executor.shutdownNow(); }
    }
    @Test @Timeout(20) void queuedPatchRechecksVersionAfterUserLock() throws Exception {
        var executor = Executors.newSingleThreadExecutor();
        var started = new CountDownLatch(1);
        final Future<?>[] pending = new Future<?>[1];
        try {
            transactions.executeWithoutResult(status -> {
                jdbc.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, userId);
                pending[0] = executor.submit(() -> {
                    authenticate(0);
                    started.countDown();
                    try { service.updateSettings(email, new NotificationSettingsRequest(false)); }
                    finally { SecurityContextHolder.clearContext(); }
                });
                try { assertTrue(started.await(5, TimeUnit.SECONDS)); }
                catch (InterruptedException e) { throw new RuntimeException(e); }
                jdbc.update("UPDATE users SET auth_version=auth_version+1 WHERE id=?", userId);
            });
            var error = assertThrows(ExecutionException.class, () -> pending[0].get(10, TimeUnit.SECONDS));
            assertInstanceOf(BadCredentialsException.class, error.getCause());
            assertTrue(service.getSettings(email).enabled());
        } finally { executor.shutdownNow(); }
    }
}
