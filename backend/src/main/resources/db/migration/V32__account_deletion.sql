ALTER TABLE users
    ADD COLUMN account_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' AFTER auth_version;

CREATE TABLE account_deletion_jobs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    provider_user_id VARCHAR(100) NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    next_attempt_at DATETIME(6) NOT NULL,
    locked_until DATETIME(6) NULL,
    last_error VARCHAR(100) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_account_deletion_provider (provider_user_id),
    INDEX idx_account_deletion_due (next_attempt_at, locked_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
