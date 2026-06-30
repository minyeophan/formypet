CREATE TABLE care_schedules (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id      BIGINT       NOT NULL,
    category_id VARCHAR(40)  NOT NULL,
    title       VARCHAR(100) NOT NULL,
    start_date  DATE         NOT NULL,
    start_time  TIME         NULL,
    end_date    DATE         NOT NULL,
    end_time    TIME         NULL,
    all_day     BOOLEAN      NOT NULL DEFAULT false,
    place       VARCHAR(200) NULL,
    memo        VARCHAR(500) NULL,
    reminder    VARCHAR(100) NOT NULL,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_care_schedule_pet FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE,
    INDEX idx_care_schedules_pet_date (pet_id, start_date, end_date, id),
    INDEX idx_care_schedules_pet_category_date (pet_id, category_id, start_date, id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
