package com.formypet.user;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.concurrent.atomic.AtomicBoolean;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.account-deletion.webhook-scheduler-enabled", havingValue = "true", matchIfMissing = true)
public class KakaoUnlinkWebhookWorker {
    private final JdbcTemplate jdbc;
    private final PlatformTransactionManager transactionManager;
    private final KakaoUnlinkWebhookEventProcessor processor;
    private final AtomicBoolean running = new AtomicBoolean();

    private record Event(long id, String providerUserId, int attempts) {}

    @Scheduled(fixedDelayString = "${app.account-deletion.webhook-interval-ms:5000}")
    public void dispatch() {
        processOne();
    }

    public boolean processOne() {
        if (!running.compareAndSet(false, true)) return false;
        try {
            Event event = claim();
            if (event == null) return false;
            try {
                processor.process(event.id(), event.providerUserId());
                return true;
            } catch (RuntimeException failure) {
                reschedule(event, failure);
                return false;
            }
        } finally {
            running.set(false);
        }
    }

    private Event claim() {
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        return tx.execute(status -> {
            var due = jdbc.query("""
                    SELECT id,provider_user_id,attempts FROM kakao_unlink_webhook_events
                    WHERE next_attempt_at<=UTC_TIMESTAMP(6)
                      AND (locked_until IS NULL OR locked_until<UTC_TIMESTAMP(6))
                    ORDER BY next_attempt_at,id LIMIT 1 FOR UPDATE SKIP LOCKED
                    """, (rs, row) -> new Event(rs.getLong("id"), rs.getString("provider_user_id"), rs.getInt("attempts")));
            if (due.isEmpty()) return null;
            Event event = due.getFirst();
            jdbc.update("UPDATE kakao_unlink_webhook_events SET locked_until=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 5 MINUTE) WHERE id=?", event.id());
            return event;
        });
    }

    private void reschedule(Event event, RuntimeException failure) {
        int attempts = Math.min(event.attempts() + 1, 30);
        long delaySeconds = Math.min(86400L, 30L << Math.min(attempts - 1, 11));
        jdbc.update("""
                UPDATE kakao_unlink_webhook_events
                SET attempts=?,next_attempt_at=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL ? SECOND),
                    locked_until=NULL,last_error=?
                WHERE id=?
                """, attempts, delaySeconds, failure.getClass().getSimpleName(), event.id());
        log.warn("Kakao unlink webhook retry scheduled: attempt={}, error={}", attempts,
                failure.getClass().getSimpleName());
    }
}
