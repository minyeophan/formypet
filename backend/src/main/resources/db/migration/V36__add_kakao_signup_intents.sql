CREATE TABLE kakao_signup_intents (
    provider_user_id VARCHAR(100) PRIMARY KEY,
    token_hash CHAR(64) NOT NULL UNIQUE,
    expires_at DATETIME(6) NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    INDEX idx_kakao_signup_expiry(expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
