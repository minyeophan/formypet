ALTER TABLE users
    ADD COLUMN profile_media_id BIGINT NULL AFTER nickname,
    ADD CONSTRAINT fk_user_profile_media
        FOREIGN KEY (profile_media_id) REFERENCES media_resources (id)
        ON DELETE SET NULL;
