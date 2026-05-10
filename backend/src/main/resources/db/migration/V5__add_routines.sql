CREATE TABLE routines (
    id                   BIGINT       AUTO_INCREMENT PRIMARY KEY,
    pet_id               BIGINT       NOT NULL,
    label                VARCHAR(100) NOT NULL,
    type_id              VARCHAR(30)  NOT NULL,
    repeat_type          ENUM('daily','weekly','biweekly','monthly') NOT NULL,
    days                 JSON,
    monthly_interval     INT          NOT NULL DEFAULT 1,
    start_date           DATE         NOT NULL,
    end_date             DATE,
    times                JSON,
    is_active            BOOLEAN      NOT NULL DEFAULT true,
    notification_enabled BOOLEAN      NOT NULL DEFAULT false,
    created_at           DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at           DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_routine_pet FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE,
    CONSTRAINT fk_routine_type FOREIGN KEY (type_id) REFERENCES activity_types (id),
    INDEX idx_routine_pet_active (pet_id, is_active)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE routine_completions (
    id                 BIGINT      AUTO_INCREMENT PRIMARY KEY,
    routine_id         BIGINT      NOT NULL,
    pet_id             BIGINT      NOT NULL,
    activity_record_id BIGINT,
    scheduled_date     DATE        NOT NULL,
    status             ENUM('PENDING','COMPLETED','SKIPPED') NOT NULL DEFAULT 'PENDING',
    completed_at       DATETIME(6),
    created_at         DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_completion_routine FOREIGN KEY (routine_id) REFERENCES routines (id) ON DELETE CASCADE,
    CONSTRAINT fk_completion_pet FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE,
    CONSTRAINT fk_completion_record FOREIGN KEY (activity_record_id) REFERENCES activity_records (id) ON DELETE SET NULL,
    UNIQUE KEY uq_routine_date (routine_id, scheduled_date),
    INDEX idx_pet_scheduled (pet_id, scheduled_date)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
