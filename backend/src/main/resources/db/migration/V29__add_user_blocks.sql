CREATE TABLE user_blocks (
    blocker_user_id BIGINT NOT NULL,
    blocked_user_id BIGINT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (blocker_user_id, blocked_user_id),
    CONSTRAINT fk_user_blocks_blocker FOREIGN KEY (blocker_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_blocks_blocked FOREIGN KEY (blocked_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
