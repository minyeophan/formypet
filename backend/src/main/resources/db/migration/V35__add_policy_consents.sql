CREATE TABLE policy_consents (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    document_type VARCHAR(32) NOT NULL,
    document_version VARCHAR(64) NOT NULL,
    acceptance_revision VARCHAR(64) NULL,
    action VARCHAR(32) NOT NULL,
    document_hash CHAR(64) NOT NULL,
    recorded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_policy_consent_user FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uq_policy_action(user_id,document_type,document_version,action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
