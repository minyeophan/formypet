CREATE TABLE activity_types (
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
    ('sleep',    'sleep',    8),
    ('play',     'play',     9),
    ('checkup',  'checkup', 10);

CREATE TABLE activity_records (
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

CREATE TABLE record_meal (
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

CREATE TABLE record_water (
    record_id BIGINT PRIMARY KEY,
    amount    DECIMAL(7,2),
    CONSTRAINT fk_record_water_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE record_medicine (
    record_id     BIGINT PRIMARY KEY,
    medicine_name VARCHAR(100),
    ingredients   VARCHAR(200),
    dosage        VARCHAR(100),
    CONSTRAINT fk_record_medicine_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE record_poop (
    record_id    BIGINT PRIMARY KEY,
    poop_shape   VARCHAR(30),
    poop_color   VARCHAR(30),
    poop_amount  VARCHAR(30),
    poop_smell   VARCHAR(30),
    CONSTRAINT fk_record_poop_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE record_walk (
    record_id      BIGINT PRIMARY KEY,
    distance       DECIMAL(8,2),
    duration       INT,
    start_location POINT SRID 4326,
    end_location   POINT SRID 4326,
    CONSTRAINT fk_record_walk_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE record_weight (
    record_id BIGINT PRIMARY KEY,
    weight    DECIMAL(5,2),
    CONSTRAINT fk_record_weight_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

CREATE TABLE record_vet (
    record_id           BIGINT PRIMARY KEY,
    vet_clinic_name     VARCHAR(100),
    clinic_location     POINT SRID 4326,
    vet_visit_reason    VARCHAR(30),
    vet_diagnosis       TEXT,
    vet_treatment       TEXT,
    vet_cost            INT,
    vet_next_visit_date DATE,
    CONSTRAINT fk_record_vet_record FOREIGN KEY (record_id) REFERENCES activity_records (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
