CREATE TABLE support_tickets (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    requester_user_id BIGINT NULL,
    kind VARCHAR(20) NOT NULL,
    request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    payload_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    category VARCHAR(30) NOT NULL,
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    reply_email VARCHAR(254) NULL,
    target_post_id BIGINT NULL,
    target_snapshot MEDIUMTEXT NULL,
    created_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_support_requester FOREIGN KEY (requester_user_id) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE KEY uq_support_request (requester_user_id, kind, request_id),
    UNIQUE KEY uq_support_report (requester_user_id, target_post_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE support_mail_outbox (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    ticket_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    attempts INT NOT NULL DEFAULT 0,
    next_attempt_at DATETIME(6) NOT NULL,
    lease_until DATETIME(6) NULL,
    claim_token CHAR(36) NULL,
    sent_at DATETIME(6) NULL,
    last_error VARCHAR(100) NULL,
    CONSTRAINT fk_support_mail_ticket FOREIGN KEY (ticket_id) REFERENCES support_tickets(id),
    UNIQUE KEY uq_support_mail_ticket (ticket_id),
    INDEX idx_support_mail_due (status, next_attempt_at),
    INDEX idx_support_mail_lease (status, lease_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
