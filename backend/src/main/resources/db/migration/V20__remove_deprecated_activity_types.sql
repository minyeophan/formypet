CREATE TABLE IF NOT EXISTS media_cleanup_queue (
    storage_key VARCHAR(500) PRIMARY KEY,
    created_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

INSERT INTO media_cleanup_queue (storage_key)
SELECT media.storage_key
FROM media_resources media
JOIN activity_records record ON record.id = media.record_id
WHERE record.type_id IN ('play', 'sleep', 'checkup')
  AND NOT EXISTS (
      SELECT 1
      FROM media_cleanup_queue queued
      WHERE queued.storage_key = media.storage_key
  );

UPDATE activity_records record
JOIN routines routine ON routine.id = record.routine_id
SET record.routine_id = NULL
WHERE routine.type_id IN ('play', 'sleep', 'checkup');

DELETE FROM routines
WHERE type_id IN ('play', 'sleep', 'checkup');

DELETE FROM activity_records
WHERE type_id IN ('play', 'sleep', 'checkup');

DELETE FROM activity_types
WHERE id IN ('play', 'sleep', 'checkup');
