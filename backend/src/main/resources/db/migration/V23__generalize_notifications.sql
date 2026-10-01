ALTER TABLE notifications
    MODIFY actor_user_id BIGINT NULL,
    MODIFY actor_nickname VARCHAR(50) NULL,
    MODIFY type VARCHAR(40) NOT NULL,
    MODIFY post_id BIGINT NULL,
    ADD source_type VARCHAR(30) NULL,
    ADD source_id BIGINT NULL,
    ADD scheduled_for DATETIME(6) NULL,
    ADD UNIQUE KEY uq_notification_reminder (recipient_user_id, source_type, source_id, scheduled_for, type);
