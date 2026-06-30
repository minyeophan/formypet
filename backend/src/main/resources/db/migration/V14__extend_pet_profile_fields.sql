ALTER TABLE pets
    ADD COLUMN breed VARCHAR(80),
    ADD COLUMN adoption_date DATE,
    ADD COLUMN guardian_nickname VARCHAR(30),
    ADD COLUMN special_status VARCHAR(30),
    ADD COLUMN personality TEXT,
    ADD COLUMN primary_hospital_name VARCHAR(100);
