ALTER TABLE media_resources
    ADD COLUMN media_kind VARCHAR(30) NOT NULL DEFAULT 'GENERAL';

UPDATE media_resources SET media_kind='PET_PROFILE'
WHERE pet_id IS NOT NULL AND record_id IS NULL;

UPDATE media_resources SET media_kind='ACTIVITY_RECORD'
WHERE record_id IS NOT NULL;

ALTER TABLE idempotency_requests ADD COLUMN result_version BIGINT NULL;

CREATE TABLE pet_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    entry_at DATETIME(6) NOT NULL,
    note VARCHAR(2000),
    version BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_pet_log_pet FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_log_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_pet_log_timeline (pet_id, entry_at, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pet_log_media (
    media_id BIGINT PRIMARY KEY,
    pet_log_id BIGINT NOT NULL,
    position INT NOT NULL,
    width INT NOT NULL,
    height INT NOT NULL,
    CONSTRAINT fk_pet_log_media_file FOREIGN KEY (media_id) REFERENCES media_resources(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_log_media_log FOREIGN KEY (pet_log_id) REFERENCES pet_logs(id) ON DELETE CASCADE,
    UNIQUE KEY uq_pet_log_media_position (pet_log_id, position),
    INDEX idx_pet_log_media_log (pet_log_id, position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pet_log_preferences (
    pet_id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    example_dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_pet_log_pref_pet FOREIGN KEY (pet_id) REFERENCES pets(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_log_pref_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
