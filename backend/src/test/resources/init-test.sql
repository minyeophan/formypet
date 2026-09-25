CREATE TABLE IF NOT EXISTS users (
    id            BIGINT         AUTO_INCREMENT PRIMARY KEY,
    email         VARCHAR(255)   NOT NULL UNIQUE,
    password_hash VARCHAR(255)   NOT NULL,
    auth_version BIGINT NOT NULL DEFAULT 0,
    account_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    nickname      VARCHAR(50)    NOT NULL,
    notification_enabled BOOLEAN  NOT NULL DEFAULT TRUE,
    registration_source VARCHAR(20) NOT NULL DEFAULT 'LOCAL',
    role VARCHAR(20) NOT NULL DEFAULT 'USER',
    profile_media_id BIGINT      NULL,
    created_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE password_reset_challenges (
    id CHAR(43) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
    subject_key CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id BIGINT NULL,
    code_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    state VARCHAR(20) NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    verify_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    reset_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    reset_expires_at DATETIME(6) NULL,
    confirm_request_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    confirm_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    completed_at DATETIME(6) NULL,
    CONSTRAINT fk_reset_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uq_reset_hash (reset_hash),
    INDEX idx_reset_subject (subject_key, state),
    INDEX idx_reset_cleanup (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE account_deletion_jobs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    provider_user_id VARCHAR(100) NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    next_attempt_at DATETIME(6) NOT NULL,
    locked_until DATETIME(6) NULL,
    last_error VARCHAR(100) NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    UNIQUE KEY uq_account_deletion_provider (provider_user_id),
    INDEX idx_account_deletion_due (next_attempt_at, locked_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE password_reset_limits (
    bucket_key CHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
    window_start DATETIME(6) NOT NULL,
    last_request_at DATETIME(6) NOT NULL,
    request_count INT NOT NULL,
    INDEX idx_reset_limit_cleanup (last_request_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS oauth_accounts (
    id               BIGINT       AUTO_INCREMENT PRIMARY KEY,
    user_id          BIGINT       NOT NULL,
    provider         VARCHAR(20)  NOT NULL,
    provider_user_id VARCHAR(100) NOT NULL,
    created_at       DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_oauth_account_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    UNIQUE KEY uq_oauth_provider_user (provider, provider_user_id),
    INDEX idx_oauth_user_id (user_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          BIGINT       AUTO_INCREMENT PRIMARY KEY,
    user_id     BIGINT       NOT NULL,
    token       VARCHAR(512) NOT NULL UNIQUE,
    expires_at  DATETIME(6)  NOT NULL,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_rt_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE INDEX idx_rt_token   ON refresh_tokens (token);
CREATE INDEX idx_rt_user_id ON refresh_tokens (user_id);

CREATE TABLE IF NOT EXISTS pets (
    id                          BIGINT          AUTO_INCREMENT PRIMARY KEY,
    user_id                     BIGINT          NOT NULL,
    name                        VARCHAR(50)     NOT NULL,
    species                     VARCHAR(30)     NOT NULL,
    birth_date                  DATE,
    breed                       VARCHAR(80),
    adoption_date               DATE,
    gender                      ENUM('male','female'),
    weight                      DECIMAL(5,2),
    animal_registration_number  VARCHAR(20),
    neutered                    BOOLEAN,
    diseases                    TEXT,
    special_notes               TEXT,
    guardian_nickname           VARCHAR(30),
    special_status              VARCHAR(30),
    personality                 TEXT,
    primary_hospital_name       VARCHAR(100),
    accent_color                VARCHAR(7)      NOT NULL,
    bg_light                    VARCHAR(7)      NOT NULL,
    is_deleted                  BOOLEAN         NOT NULL DEFAULT false,
    created_at                  DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at                  DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_pet_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX idx_user_active (user_id, is_deleted)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS activity_types (
    id            VARCHAR(30)  PRIMARY KEY,
    name          VARCHAR(50)  NOT NULL,
    icon_url      VARCHAR(200),
    display_order INT          NOT NULL DEFAULT 0
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

INSERT INTO activity_types (id, name, display_order) VALUES
    ('meal',     'meal',     1),
    ('water',    'water',    2),
    ('walk',     'walk',     3),
    ('medicine', 'medicine', 4),
    ('poop',     'poop',     5),
    ('weight',   'weight',   6),
    ('vet',      'vet',      7),
    ('diary',    'diary',   11),
    ('etc',      'etc',     12);

CREATE TABLE IF NOT EXISTS activity_records (
    id         BIGINT      AUTO_INCREMENT PRIMARY KEY,
    pet_id     BIGINT      NOT NULL,
    type_id    VARCHAR(30) NOT NULL,
    date       DATE        NOT NULL,
    time       TIME,
    note       TEXT,
    routine_id BIGINT,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_activity_record_pet FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE,
    CONSTRAINT fk_activity_record_type FOREIGN KEY (type_id) REFERENCES activity_types (id),
    INDEX idx_pet_date (pet_id, date),
    INDEX idx_pet_type (pet_id, type_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS record_meal (
    record_id        BIGINT PRIMARY KEY,
    food_type        VARCHAR(30),
    feeding_method   VARCHAR(30),
    served_amount    DECIMAL(7,2),
    consumed_amount  DECIMAL(7,2),
    consumed_percent DECIMAL(5,2),
    brand            VARCHAR(100),
    product          VARCHAR(100),
    ingredients      TEXT,
    CONSTRAINT fk_record_meal_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS record_water (
    record_id BIGINT PRIMARY KEY,
    amount    DECIMAL(7,2),
    CONSTRAINT fk_record_water_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS record_medicine (
    record_id     BIGINT PRIMARY KEY,
    medicine_name VARCHAR(100),
    ingredients   VARCHAR(200),
    dosage        VARCHAR(100),
    CONSTRAINT fk_record_medicine_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS record_poop (
    record_id    BIGINT PRIMARY KEY,
    poop_shape   VARCHAR(30),
    poop_color   VARCHAR(30),
    poop_amount  VARCHAR(30),
    poop_smell   VARCHAR(30),
    CONSTRAINT fk_record_poop_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS record_walk (
    record_id      BIGINT PRIMARY KEY,
    distance       DECIMAL(8,2),
    duration       INT,
    CONSTRAINT fk_record_walk_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS record_weight (
    record_id BIGINT PRIMARY KEY,
    weight    DECIMAL(5,2),
    CONSTRAINT fk_record_weight_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS record_vet (
    record_id           BIGINT PRIMARY KEY,
    vet_clinic_name     VARCHAR(100),
    vet_visit_reason    VARCHAR(30),
    vet_diagnosis       TEXT,
    vet_treatment       TEXT,
    vet_cost            INT,
    vet_next_visit_date DATE,
    CONSTRAINT fk_record_vet_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS routines (
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
    note                 TEXT,
    detail               JSON,
    is_active            BOOLEAN      NOT NULL DEFAULT true,
    notification_enabled BOOLEAN      NOT NULL DEFAULT false,
    created_at           DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at           DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_routine_pet FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE,
    CONSTRAINT fk_routine_type FOREIGN KEY (type_id) REFERENCES activity_types (id),
    INDEX idx_routine_pet_active (pet_id, is_active)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS routine_completions (
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

CREATE TABLE IF NOT EXISTS wallet_expenses (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id      BIGINT NOT NULL,
    pet_id       BIGINT NOT NULL,
    expense_date DATE NOT NULL,
    expense_time TIME NULL,
    amount       BIGINT NOT NULL,
    currency     VARCHAR(3) NOT NULL DEFAULT 'KRW',
    category     VARCHAR(40) NOT NULL,
    item_name    VARCHAR(100) NULL,
    note         VARCHAR(500) NULL,
    created_at   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_wallet_expense_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_wallet_expense_pet FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE,
    INDEX idx_wallet_expenses_pet_date (pet_id, expense_date, expense_time, id),
    INDEX idx_wallet_expenses_user_date (user_id, expense_date, expense_time, id),
    INDEX idx_wallet_expenses_pet_category_date (pet_id, category, expense_date, expense_time, id),
    INDEX idx_wallet_expenses_user_category_date (user_id, category, expense_date, expense_time, id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS care_schedules (
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

CREATE TABLE IF NOT EXISTS posts (
    id           BIGINT       AUTO_INCREMENT PRIMARY KEY,
    user_id      BIGINT       NOT NULL,
    title        VARCHAR(120) NOT NULL DEFAULT '제목 없음',
    category     VARCHAR(30)  NOT NULL DEFAULT 'FREE',
    pet_species  VARCHAR(30),
    content      TEXT         NOT NULL,
    likes_count  INT          NOT NULL DEFAULT 0,
    comments_count INT        NOT NULL DEFAULT 0,
    created_at   DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_post_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX idx_post_id_desc (id DESC),
    INDEX idx_post_category_latest (category, id DESC),
    INDEX idx_post_popular (likes_count DESC, id DESC)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS post_likes (
    user_id    BIGINT      NOT NULL,
    post_id    BIGINT      NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (user_id, post_id),
    CONSTRAINT fk_post_like_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_like_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS post_comments (
    id         BIGINT        AUTO_INCREMENT PRIMARY KEY,
    post_id    BIGINT        NOT NULL,
    user_id    BIGINT        NOT NULL,
    parent_comment_id BIGINT NULL,
    content    VARCHAR(1000) NOT NULL,
    created_at DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6)   NULL,
    deleted_at DATETIME(6)   NULL,
    CONSTRAINT fk_post_comment_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_comment_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_comment_parent FOREIGN KEY (parent_comment_id) REFERENCES post_comments (id) ON DELETE CASCADE,
    INDEX idx_post_comment_cursor (post_id, id DESC),
    INDEX idx_post_comments_active_thread (post_id, parent_comment_id, deleted_at, id DESC)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS post_comment_reports (
    id               BIGINT        AUTO_INCREMENT PRIMARY KEY,
    comment_id       BIGINT        NOT NULL,
    reporter_user_id BIGINT        NOT NULL,
    reason           VARCHAR(30)   NOT NULL,
    detail           VARCHAR(500)  NULL,
    content_snapshot VARCHAR(1000) NOT NULL,
    created_at       DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_post_comment_report_comment FOREIGN KEY (comment_id) REFERENCES post_comments (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_comment_report_user FOREIGN KEY (reporter_user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uk_post_comment_reporter UNIQUE (comment_id, reporter_user_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS media_resources (
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
    visibility    VARCHAR(20)  NOT NULL DEFAULT 'PRIVATE',
    created_at    DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_media_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_media_pet FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE,
    CONSTRAINT fk_media_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE,
    INDEX idx_media_user (user_id),
    INDEX idx_media_pet (pet_id),
    INDEX idx_media_record (record_id),
    INDEX idx_media_visibility (visibility)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS media_cleanup_queue (
    storage_key VARCHAR(500) PRIMARY KEY,
    created_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS post_media (
    post_id    BIGINT NOT NULL,
    media_id   BIGINT NOT NULL,
    sort_order INT    NOT NULL DEFAULT 0,
    PRIMARY KEY (post_id, media_id),
    CONSTRAINT fk_post_media_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_media_media FOREIGN KEY (media_id) REFERENCES media_resources (id) ON DELETE CASCADE,
    INDEX idx_post_media_order (post_id, sort_order)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS post_polls (
    id       BIGINT       AUTO_INCREMENT PRIMARY KEY,
    post_id  BIGINT       NOT NULL UNIQUE,
    question VARCHAR(200) NOT NULL,
    CONSTRAINT fk_post_poll_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS post_poll_options (
    id          BIGINT       AUTO_INCREMENT PRIMARY KEY,
    poll_id     BIGINT       NOT NULL,
    label       VARCHAR(100) NOT NULL,
    votes_count INT          NOT NULL DEFAULT 0,
    sort_order  INT          NOT NULL DEFAULT 0,
    CONSTRAINT fk_poll_option_poll FOREIGN KEY (poll_id) REFERENCES post_polls (id) ON DELETE CASCADE,
    INDEX idx_poll_option_order (poll_id, sort_order)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS post_poll_votes (
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

ALTER TABLE users
    ADD CONSTRAINT fk_user_profile_media
        FOREIGN KEY (profile_media_id) REFERENCES media_resources (id)
        ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    recipient_user_id BIGINT NOT NULL, actor_user_id BIGINT NULL,
    actor_nickname VARCHAR(50) NULL, type VARCHAR(40) NOT NULL,
    post_id BIGINT NULL, comment_id BIGINT NULL,
    source_type VARCHAR(30) NULL, source_id BIGINT NULL, scheduled_for DATETIME(6) NULL,
    title VARCHAR(120) NOT NULL, body VARCHAR(500) NOT NULL,
    read_at DATETIME(6) NULL, created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    FOREIGN KEY (recipient_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (comment_id) REFERENCES post_comments(id) ON DELETE CASCADE,
    INDEX idx_notifications_recipient_cursor (recipient_user_id, id DESC),
    INDEX idx_notifications_unread (recipient_user_id, read_at),
    UNIQUE KEY uq_notification_reminder (recipient_user_id, source_type, source_id, scheduled_for, type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

CREATE TABLE user_blocks (
    blocker_user_id BIGINT NOT NULL,
    blocked_user_id BIGINT NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (blocker_user_id, blocked_user_id),
    CONSTRAINT fk_user_blocks_blocker FOREIGN KEY (blocker_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_blocks_blocked FOREIGN KEY (blocked_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE device_tokens (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    token VARCHAR(512) NOT NULL,
    platform VARCHAR(20) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    UNIQUE KEY uk_device_token (token),
    INDEX idx_device_tokens_user (user_id),
    CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
