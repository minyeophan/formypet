ALTER TABLE record_walk
    DROP COLUMN start_location,
    DROP COLUMN end_location;

ALTER TABLE record_vet
    DROP COLUMN clinic_location;

UPDATE routines
SET detail = JSON_REMOVE(
        detail,
        '$.startLng', '$.startLat', '$.endLng', '$.endLat', '$.clinicLng', '$.clinicLat'
    )
WHERE detail IS NOT NULL
  AND JSON_TYPE(detail) = 'OBJECT';

DROP TABLE spatial_test;
