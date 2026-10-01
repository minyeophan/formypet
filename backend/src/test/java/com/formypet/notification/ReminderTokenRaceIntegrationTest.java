package com.formypet.notification;

import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class ReminderTokenRaceIntegrationTest extends IntegrationTestSupport {
    @Autowired JdbcTemplate jdbc;
    @Autowired ReminderPushDispatcher dispatcher;
    @MockitoBean PushSender sender;
    long owner;
    long other;
    long routine;
    String token;
    final LocalDateTime due = LocalDateTime.of(2026, 9, 18, 9, 0);

    @BeforeEach void seed() {
        token = UUID.randomUUID().toString();
        owner = user(token + "@a.test");
        other = user(token + "@b.test");
        jdbc.update("INSERT INTO pets(user_id,name,species,accent_color,bg_light) VALUES (?,'test','dog','#000000','#ffffff')", owner);
        long pet = jdbc.queryForObject("SELECT id FROM pets WHERE user_id=?", Long.class, owner);
        jdbc.update("""
            INSERT INTO routines(pet_id,label,type_id,repeat_type,days,monthly_interval,start_date,times,notification_enabled)
            VALUES (?,'test','water','daily','[]',1,'2026-09-18','["09:00"]',TRUE)
            """, pet);
        routine = jdbc.queryForObject("SELECT id FROM routines WHERE pet_id=?", Long.class, pet);
        jdbc.update("INSERT INTO device_tokens(user_id,token,platform,enabled,updated_at) VALUES (?,?,'ANDROID',TRUE,'2000-01-01')", owner, token);
    }
    long user(String email) {
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'not-a-real-password','test')", email);
        return jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
    }
    void dispatch() { dispatcher.dispatch(owner, NotificationType.ROUTINE_REMINDER, routine, due, "test", "test"); }
    boolean enabled() { return jdbc.queryForObject("SELECT enabled FROM device_tokens WHERE token=?", Boolean.class, token); }

    @Test void unregisteredDeviceIsDisabledAndCommitted() {
        when(sender.send(any(), any(), any(), any(), any())).thenReturn(new PushSendResult(0, 1, List.of(token)));
        dispatch();
        assertFalse(enabled());
    }
    @Test void lateInvalidResultCannotDisableTokenTransferredToAnotherAccount() {
        when(sender.send(any(), any(), any(), any(), any())).thenAnswer(call -> {
            CompletableFuture.runAsync(() -> jdbc.update(
                "UPDATE device_tokens SET user_id=?,updated_at=CURRENT_TIMESTAMP(6) WHERE token=?", other, token)).join();
            return new PushSendResult(0, 1, List.of(token));
        });
        dispatch();
        assertTrue(enabled());
        assertEquals(other, jdbc.queryForObject("SELECT user_id FROM device_tokens WHERE token=?", Long.class, token));
    }
    @Test void lateInvalidResultCannotDisableNewRegistrationForSameAccount() {
        when(sender.send(any(), any(), any(), any(), any())).thenAnswer(call -> {
            CompletableFuture.runAsync(() -> jdbc.update(
                "UPDATE device_tokens SET updated_at=CURRENT_TIMESTAMP(6) WHERE token=?", token)).join();
            return new PushSendResult(0, 1, List.of(token));
        });
        dispatch();
        assertTrue(enabled());
    }
    @Test void temporaryFailureKeepsDeviceEnabled() {
        when(sender.send(any(), any(), any(), any(), any())).thenReturn(new PushSendResult(0, 1, List.of()));
        dispatch();
        assertTrue(enabled());
    }
    @Test void deletionBeforeDispatchPreventsSending() {
        jdbc.update("DELETE FROM routines WHERE id=?", routine);
        dispatch();
        verifyNoInteractions(sender);
        assertTrue(enabled());
    }
}
