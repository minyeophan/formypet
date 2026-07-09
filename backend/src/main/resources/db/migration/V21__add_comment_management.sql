ALTER TABLE post_comments
    ADD COLUMN updated_at DATETIME(6) NULL AFTER created_at,
    ADD COLUMN deleted_at DATETIME(6) NULL AFTER updated_at,
    DROP INDEX idx_post_comments_thread_cursor,
    ADD INDEX idx_post_comments_active_thread (post_id, parent_comment_id, deleted_at, id DESC);

CREATE TABLE post_comment_reports (
    id               BIGINT        AUTO_INCREMENT PRIMARY KEY,
    comment_id       BIGINT        NOT NULL,
    reporter_user_id BIGINT        NOT NULL,
    reason           VARCHAR(30)   NOT NULL,
    detail           VARCHAR(500)  NULL,
    content_snapshot VARCHAR(1000) NOT NULL,
    created_at       DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_post_comment_report_comment
        FOREIGN KEY (comment_id) REFERENCES post_comments (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_comment_report_user
        FOREIGN KEY (reporter_user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uk_post_comment_reporter UNIQUE (comment_id, reporter_user_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
