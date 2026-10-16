package com.formypet.domain.user.repository.jdbc;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class KakaoWebhookRepository {
    private final JdbcTemplate jdbc;
    public record Event(long id, String providerUserId, int attempts) {}

    public void enqueue(String providerUserId) {
        jdbc.update("INSERT IGNORE INTO kakao_unlink_webhook_events(provider_user_id,next_attempt_at) VALUES (?,UTC_TIMESTAMP(6))", providerUserId);
    }

    /** Caller provides the short transaction covering selection and lease assignment. */
    public Event claim() {
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
    }
    public boolean lockEvent(long eventId, String providerUserId) {
        return !jdbc.queryForList("SELECT id FROM kakao_unlink_webhook_events WHERE id=? AND provider_user_id=? FOR UPDATE", Long.class, eventId, providerUserId).isEmpty();
    }
    public void delete(long id) {
        jdbc.update("DELETE FROM kakao_unlink_webhook_events WHERE id=?", id);
    }
    public void reschedule(long id, int attempts, long delaySeconds, String errorClass) {
        jdbc.update("""
                UPDATE kakao_unlink_webhook_events
                SET attempts=?,next_attempt_at=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL ? SECOND),
                    locked_until=NULL,last_error=? WHERE id=?
                """, attempts, delaySeconds, errorClass, id);
    }
}
