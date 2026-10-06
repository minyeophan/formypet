CREATE TABLE kakao_unlink_webhook_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    provider_user_id VARCHAR(100) NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    next_attempt_at DATETIME(6) NOT NULL,
    locked_until DATETIME(6) NULL,
    last_error VARCHAR(100) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_kakao_unlink_event_provider (provider_user_id),
    INDEX idx_kakao_unlink_event_due (next_attempt_at, locked_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
