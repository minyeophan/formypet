package com.formypet.domain.notification;

import com.formypet.domain.notification.entity.Notification;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.repository.DeviceTokenRepository;
import com.formypet.domain.notification.repository.NotificationRepository;
import com.formypet.domain.notification.repository.jdbc.NotificationCommands;
import com.formypet.support.IntegrationTestSupport;
import jakarta.persistence.EntityManager;
import java.time.LocalDateTime;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.*;

@Transactional
class NotificationRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired NotificationRepository notifications;
    @Autowired DeviceTokenRepository tokens;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager entities;
    @Autowired NotificationCommands commands;

    @Test void feedAndTokenProjectionsDoNotLoadManagedEntitiesAndJpaQueriesStayConstant() {
        long owner = user();
        var now = LocalDateTime.now(java.time.ZoneOffset.UTC);
        for (int i = 0; i < 50; i++) {
            notifications.saveAndFlush(Notification.activity(owner, null, null, NotificationType.COMMENT,
                    null, null, "title", "body", now));
            commands.registerToken(owner, "cost-" + UUID.randomUUID(), "ANDROID");
        }
        entities.clear();
        var stats = entities.getEntityManagerFactory().unwrap(org.hibernate.SessionFactory.class).getStatistics();
        boolean enabled = stats.isStatisticsEnabled();
        stats.setStatisticsEnabled(true);
        try {
            stats.clear();
            assertThat(notifications.findVisible(owner, null, 51)).hasSize(50);
            assertThat(stats.getEntityLoadCount()).isZero();
            assertThat(stats.getPrepareStatementCount()).isZero(); // one JDBC fragment query, outside Hibernate
            assertThat(notifications.countUnreadVisible(owner)).isEqualTo(50);
            assertThat(stats.getPrepareStatementCount()).isEqualTo(1);
            assertThat(tokens.activeSnapshots(owner)).hasSize(50);
            assertThat(stats.getPrepareStatementCount()).isEqualTo(2);
            assertThat(stats.getEntityLoadCount()).isZero();
        } finally { stats.setStatisticsEnabled(enabled); }
    }

    @Test void feedCountAndReadCommandsShareAgeOwnershipAndBlockVisibility() {
        long owner = user(), blocked = user(), other = user();
        jdbc.update("INSERT INTO user_blocks(blocker_user_id,blocked_user_id) VALUES (?,?)", owner, blocked);
        var now = LocalDateTime.now(java.time.ZoneOffset.UTC).withNano(123456000);
        long visible = activity(owner, other, null, now);
        long hidden = activity(owner, blocked, null, now);
        long old = activity(owner, other, null, now.minusDays(31));
        long foreign = activity(other, owner, null, now);
        jdbc.update("INSERT INTO posts(user_id,title,category,content) VALUES (?,'title','FREE','body')", blocked);
        long post = jdbc.queryForObject("SELECT id FROM posts WHERE user_id=?", Long.class, blocked);
        long hiddenPost = activity(owner, other, post, now);
        assertThat(notifications.findVisible(owner, null, 51)).extracting(row -> row.id()).containsExactly(visible);
        assertThat(notifications.countUnreadVisible(owner)).isEqualTo(1);
        assertThat(notifications.findVisible(owner, visible, 51)).isEmpty();
        for (long id : new long[]{hidden, old, foreign, hiddenPost}) {
            assertThat(commands.markRead(owner, id, now)).isZero();
        }
        assertThat(commands.markRead(owner, visible, now)).isEqualTo(1);
        commands.markRead(owner, visible, now.plusMinutes(1));
        assertThat(notifications.findVisible(owner, null, 51).getFirst().readAt()).isEqualTo(now);
        assertThat(notifications.countUnreadVisible(owner)).isZero();
        assertThat(commands.markAllRead(owner, now)).isZero();
        assertThat(commands.blockedActivity(owner, other, post)).isTrue();
        assertThat(commands.blockedActivity(owner, blocked, null)).isTrue();
        assertThat(commands.blockedActivity(owner, other, null)).isFalse();
    }

    @Test void atomicReminderInsertKeepsOriginalBodyAndBothClockRepresentations() {
        long owner = user();
        var scheduled = LocalDateTime.parse("2026-01-02T09:00:00.123456");
        var created = scheduled.minusHours(9);
        assertThat(commands.insertReminder(owner, "ROUTINE_REMINDER", "ROUTINE", 7L,
                scheduled, "title", "body", created)).isEqualTo(1);
        assertThat(commands.insertReminder(owner, "ROUTINE_REMINDER", "ROUTINE", 7L,
                scheduled, "changed", "changed", created.plusSeconds(1))).isZero();
        long id = jdbc.queryForObject("SELECT id FROM notifications WHERE recipient_user_id=?", Long.class, owner);
        var loaded = notifications.findById(id).orElseThrow();
        assertThat(loaded.getScheduledFor()).isEqualTo(scheduled);
        assertThat(loaded.getCreatedAt()).isEqualTo(created);
        assertThat(loaded.getBody()).isEqualTo("body");
        assertThat(notifications.deletePending("ROUTINE", 7L, scheduled.plusNanos(1000))).isZero();
        assertThat(notifications.deletePending("ROUTINE", 7L, scheduled)).isEqualTo(1);
    }

    @Test void tokenSnapshotsBypassManagedStateAndInvalidationMatchesOwnerAndTimestamp() {
        long owner = user(), other = user();
        String token = "snapshot-" + UUID.randomUUID();
        commands.registerToken(owner, token, "ANDROID");
        tokens.findByToken(token).orElseThrow();
        var old = tokens.activeSnapshots(owner).getFirst();
        jdbc.update("UPDATE device_tokens SET updated_at=DATE_ADD(updated_at, INTERVAL 1 SECOND) WHERE token=?", token);
        var fresh = tokens.activeSnapshots(owner).getFirst();
        assertThat(fresh.updatedAt()).isAfter(old.updatedAt());
        assertThat(commands.disableInvalidToken(owner, token, old.updatedAt())).isZero();
        commands.registerToken(other, token, "IOS");
        assertThat(tokens.activeSnapshots(owner)).isEmpty();
        assertThat(commands.disableInvalidToken(owner, token, fresh.updatedAt())).isZero();
        var transferred = tokens.activeSnapshots(other).getFirst();
        assertThat(commands.disableInvalidToken(other, token, transferred.updatedAt())).isEqualTo(1);
        assertThat(tokens.activeSnapshots(other)).isEmpty();
        commands.registerToken(other, token, "IOS");
        assertThat(tokens.activeSnapshots(other)).hasSize(1);
        commands.disableToken(owner, token);
        assertThat(tokens.activeSnapshots(other)).hasSize(1);
        commands.disableToken(other, token);
        assertThat(tokens.activeSnapshots(other)).isEmpty();
    }

    private long activity(long recipient, long actor, Long post, LocalDateTime created) {
        return notifications.saveAndFlush(Notification.activity(recipient, actor, "actor", NotificationType.COMMENT,
                post, null, "title", "body", created)).getId();
    }

    @Test void notificationSaveAndReadKeepUtcMicrosecondsAndFirstReadTime() {
        long owner = user();
        var created = LocalDateTime.parse("2026-01-01T23:59:59.123456");
        var notification = Notification.activity(owner, null, null, NotificationType.COMMENT,
                null, null, "title", "body", created);
        notifications.saveAndFlush(notification);
        assertThat(jdbc.queryForObject("SELECT created_at FROM notifications WHERE id=?",
                LocalDateTime.class, notification.getId())).isEqualTo(created);
        entities.clear();
        var loaded = notifications.findById(notification.getId()).orElseThrow();
        assertThat(loaded.getActorUserId()).isNull();
        assertThat(loaded.getPostId()).isNull();
        assertThat(loaded.getType()).isEqualTo(NotificationType.COMMENT);
        assertThat(loaded.getCreatedAt()).isEqualTo(created);
        loaded.markRead(created.plusMinutes(1));
        loaded.markRead(created.plusMinutes(2));
        notifications.flush();
        entities.clear();
        assertThat(notifications.findById(notification.getId()).orElseThrow().getReadAt())
                .isEqualTo(created.plusMinutes(1));
    }

    @Test void legacyReminderKeepsWallClockScheduleSeparateFromUtcCreatedAt() {
        long owner = user();
        var scheduled = LocalDateTime.parse("2026-01-02T09:00:00.654321");
        var created = scheduled.minusHours(9);
        jdbc.update("""
                INSERT INTO notifications(recipient_user_id,type,title,body,source_type,source_id,scheduled_for,created_at)
                VALUES (?,'ROUTINE_REMINDER','title','body','ROUTINE',123,?,?)
                """, owner, scheduled, created);
        long id = jdbc.queryForObject("SELECT id FROM notifications WHERE recipient_user_id=?", Long.class, owner);
        var loaded = notifications.findById(id).orElseThrow();
        assertThat(loaded.getScheduledFor()).isEqualTo(scheduled);
        assertThat(loaded.getCreatedAt()).isEqualTo(created);
        assertThat(loaded.getSourceId()).isEqualTo(123L);
        assertThat(loaded.getActorNickname()).isNull();
    }

    @Test void legacyDeviceTokenKeepsDatabaseTimestampsAndOwnership() {
        long owner = user();
        String token = "notification-repository-" + UUID.randomUUID();
        var time = LocalDateTime.parse("2026-01-01T23:59:59.123456");
        jdbc.update("INSERT INTO device_tokens(user_id,token,platform,enabled,created_at,updated_at) VALUES (?,?,'IOS',FALSE,?,?)",
                owner, token, time, time.plusSeconds(1));
        var loaded = tokens.findByToken(token).orElseThrow();
        assertThat(loaded.getUserId()).isEqualTo(owner);
        assertThat(loaded.getPlatform()).isEqualTo("IOS");
        assertThat(loaded.isEnabled()).isFalse();
        assertThat(loaded.getCreatedAt()).isEqualTo(time);
        assertThat(loaded.getUpdatedAt()).isEqualTo(time.plusSeconds(1));
    }

    private long user() {
        String email = UUID.randomUUID() + "@notification-repository.test";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'test','test')", email);
        return jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
    }
}
