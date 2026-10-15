package com.formypet.domain.notification.repository.jdbc;

import com.formypet.domain.notification.repository.query.NotificationVisibility;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Atomic upserts, conditional writes and cross-domain account locks require current DB state. */
@Repository
@RequiredArgsConstructor
public class NotificationCommands {
    private final JdbcTemplate jdbc;

    public boolean blockedActivity(Long recipient, Long actor, Long post) {
        return Boolean.TRUE.equals(jdbc.queryForObject("""
                SELECT EXISTS(SELECT 1 FROM user_blocks WHERE blocker_user_id=? AND blocked_user_id=?)
                  OR EXISTS(SELECT 1 FROM posts p JOIN user_blocks b ON b.blocked_user_id=p.user_id
                            WHERE p.id=? AND b.blocker_user_id=?)
                """, Boolean.class, recipient, actor, post, recipient));
    }

    public boolean lockReminderPreference(Long recipient) {
        return jdbc.query("SELECT notification_enabled FROM users WHERE id=? FOR UPDATE",
                (rs, n) -> rs.getBoolean(1), recipient).stream().findFirst().orElse(false);
    }

    public boolean lockDispatchRecipient(Long recipient) {
        return !jdbc.query("SELECT id FROM users WHERE id=? AND account_status='ACTIVE' AND notification_enabled=1 FOR UPDATE",
                (rs, n) -> rs.getLong(1), recipient).isEmpty();
    }

    public boolean settings(Long userId) {
        return Boolean.TRUE.equals(jdbc.queryForObject("SELECT notification_enabled FROM users WHERE id=?", Boolean.class, userId));
    }

    public void updateSettings(Long userId, boolean enabled, LocalDateTime updatedAt) {
        jdbc.update("UPDATE users SET notification_enabled=?,updated_at=? WHERE id=?", enabled, updatedAt, userId);
    }

    public int insertReminder(Long recipient, String type, String sourceType, Long sourceId,
                              LocalDateTime scheduled, String title, String body, LocalDateTime created) {
        return jdbc.update("""
                INSERT IGNORE INTO notifications(recipient_user_id,type,title,body,source_type,source_id,scheduled_for,created_at)
                VALUES (?,?,?,?,?,?,?,?)
                """, recipient, type, title, body, sourceType, sourceId, scheduled, created);
    }

    public int markRead(Long recipient, Long id, LocalDateTime readAt) {
        return jdbc.update("UPDATE notifications SET read_at=COALESCE(read_at,?) WHERE id=? AND recipient_user_id=? AND "
                + NotificationVisibility.AGE + " AND " + NotificationVisibility.VISIBLE, readAt, id, recipient);
    }

    public int markAllRead(Long recipient, LocalDateTime readAt) {
        return jdbc.update("UPDATE notifications SET read_at=? WHERE recipient_user_id=? AND read_at IS NULL AND "
                + NotificationVisibility.AGE + " AND " + NotificationVisibility.VISIBLE, readAt, recipient);
    }

    public void registerToken(Long userId, String token, String platform) {
        jdbc.update("""
                INSERT INTO device_tokens(user_id,token,platform,enabled) VALUES (?,?,?,TRUE)
                ON DUPLICATE KEY UPDATE user_id=VALUES(user_id),platform=VALUES(platform),enabled=TRUE,updated_at=CURRENT_TIMESTAMP(6)
                """, userId, token, platform);
    }

    public void disableToken(Long userId, String token) {
        jdbc.update("UPDATE device_tokens SET enabled=FALSE,updated_at=CURRENT_TIMESTAMP(6) WHERE user_id=? AND token=?", userId, token);
    }

    public int disableInvalidToken(Long userId, String token, LocalDateTime snapshotTime) {
        return jdbc.update("""
                UPDATE device_tokens SET enabled=FALSE,updated_at=CURRENT_TIMESTAMP(6)
                WHERE user_id=? AND token=? AND updated_at=? AND enabled=TRUE
                """, userId, token, snapshotTime);
    }
}
