CREATE TABLE users (
    id            BIGINT         AUTO_INCREMENT PRIMARY KEY,
    email         VARCHAR(255)   NOT NULL UNIQUE,
    password_hash VARCHAR(255)   NOT NULL,
    nickname      VARCHAR(50)    NOT NULL,
    created_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE refresh_tokens (
    id          BIGINT       AUTO_INCREMENT PRIMARY KEY,
    user_id     BIGINT       NOT NULL,
    token       VARCHAR(512) NOT NULL UNIQUE,
    expires_at  DATETIME(6)  NOT NULL,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_rt_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE INDEX idx_rt_token   ON refresh_tokens (token);
CREATE INDEX idx_rt_user_id ON refresh_tokens (user_id);
