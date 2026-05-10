CREATE TABLE media_resources (
    id            BIGINT       AUTO_INCREMENT PRIMARY KEY,
    user_id       BIGINT       NOT NULL,
    pet_id        BIGINT       NULL,
    record_id     BIGINT       NULL,
    storage_key   VARCHAR(500) NOT NULL UNIQUE,
    original_name VARCHAR(255) NOT NULL,
    content_type  VARCHAR(100) NOT NULL,
    extension     VARCHAR(10)  NOT NULL,
    file_size     BIGINT       NOT NULL,
    status        ENUM('STORED') NOT NULL,
    created_at    DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_media_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_media_pet FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE,
    CONSTRAINT fk_media_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE,
    INDEX idx_media_user (user_id),
    INDEX idx_media_pet (pet_id),
    INDEX idx_media_record (record_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
