ALTER TABLE users ADD COLUMN auth_version BIGINT NOT NULL DEFAULT 0;

CREATE TABLE password_reset_challenges (
    id CHAR(43) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
    subject_key CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id BIGINT NULL,
    code_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    state VARCHAR(20) NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    verify_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    reset_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    reset_expires_at DATETIME(6) NULL,
    confirm_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    confirm_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    completed_at DATETIME(6) NULL,
    CONSTRAINT fk_reset_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uq_reset_hash (reset_hash),
    INDEX idx_reset_subject (subject_key, state),
    INDEX idx_reset_cleanup (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE password_reset_limits (
    bucket_key CHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
    window_start DATETIME(6) NOT NULL,
    last_request_at DATETIME(6) NOT NULL,
    request_count INT NOT NULL,
    INDEX idx_reset_limit_cleanup (last_request_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
