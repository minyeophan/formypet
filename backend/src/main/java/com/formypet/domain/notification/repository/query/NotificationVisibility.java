package com.formypet.domain.notification.repository.query;



/** Shared by reads and atomic mutations so hidden rows cannot be marked read. */
public final class NotificationVisibility {
    private NotificationVisibility() {}
    public static final String AGE = "created_at >= DATE_SUB(CURRENT_TIMESTAMP(6), INTERVAL 30 DAY)";
    public static final String VISIBLE = """
            NOT EXISTS (SELECT 1 FROM user_blocks b
              WHERE b.blocker_user_id=notifications.recipient_user_id AND b.blocked_user_id=notifications.actor_user_id)
            AND NOT EXISTS (SELECT 1 FROM posts p JOIN user_blocks b ON b.blocked_user_id=p.user_id
              WHERE p.id=notifications.post_id AND b.blocker_user_id=notifications.recipient_user_id)
            """;
}
