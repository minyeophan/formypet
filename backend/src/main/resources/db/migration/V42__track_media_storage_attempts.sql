-- Independent from user/media FKs: recovery must survive rollback and account deletion.
CREATE TABLE media_storage_attempts (
    storage_key VARCHAR(500) NOT NULL PRIMARY KEY,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    INDEX idx_media_attempt_age(created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
