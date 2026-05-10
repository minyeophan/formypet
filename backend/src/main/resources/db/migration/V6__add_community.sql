CREATE TABLE posts (
    id           BIGINT       AUTO_INCREMENT PRIMARY KEY,
    user_id      BIGINT       NOT NULL,
    pet_species  VARCHAR(30),
    content      TEXT         NOT NULL,
    likes_count  INT          NOT NULL DEFAULT 0,
    created_at   DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_post_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX idx_post_id_desc (id DESC)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE post_likes (
    user_id    BIGINT      NOT NULL,
    post_id    BIGINT      NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (user_id, post_id),
    CONSTRAINT fk_post_like_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_like_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
