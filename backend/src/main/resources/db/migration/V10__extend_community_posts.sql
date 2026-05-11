ALTER TABLE posts
    ADD COLUMN title VARCHAR(120) NOT NULL DEFAULT '제목 없음' AFTER user_id,
    ADD COLUMN category VARCHAR(30) NOT NULL DEFAULT 'FREE' AFTER title,
    ADD COLUMN comments_count INT NOT NULL DEFAULT 0 AFTER likes_count,
    ADD INDEX idx_post_category_latest (category, id DESC),
    ADD INDEX idx_post_popular (likes_count DESC, id DESC);

ALTER TABLE media_resources
    ADD COLUMN visibility VARCHAR(20) NOT NULL DEFAULT 'PRIVATE' AFTER status,
    ADD INDEX idx_media_visibility (visibility);

CREATE TABLE post_media (
    post_id    BIGINT NOT NULL,
    media_id   BIGINT NOT NULL,
    sort_order INT    NOT NULL DEFAULT 0,
    PRIMARY KEY (post_id, media_id),
    CONSTRAINT fk_post_media_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_media_media FOREIGN KEY (media_id) REFERENCES media_resources (id) ON DELETE CASCADE,
    INDEX idx_post_media_order (post_id, sort_order)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE post_polls (
    id       BIGINT       AUTO_INCREMENT PRIMARY KEY,
    post_id  BIGINT       NOT NULL UNIQUE,
    question VARCHAR(200) NOT NULL,
    CONSTRAINT fk_post_poll_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE post_poll_options (
    id          BIGINT       AUTO_INCREMENT PRIMARY KEY,
    poll_id     BIGINT       NOT NULL,
    label       VARCHAR(100) NOT NULL,
    votes_count INT          NOT NULL DEFAULT 0,
    sort_order  INT          NOT NULL DEFAULT 0,
    CONSTRAINT fk_poll_option_poll FOREIGN KEY (poll_id) REFERENCES post_polls (id) ON DELETE CASCADE,
    INDEX idx_poll_option_order (poll_id, sort_order)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE post_poll_votes (
    poll_id    BIGINT NOT NULL,
    user_id    BIGINT NOT NULL,
    option_id  BIGINT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (poll_id, user_id),
    CONSTRAINT fk_poll_vote_poll FOREIGN KEY (poll_id) REFERENCES post_polls (id) ON DELETE CASCADE,
    CONSTRAINT fk_poll_vote_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_poll_vote_option FOREIGN KEY (option_id) REFERENCES post_poll_options (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
