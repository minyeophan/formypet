ALTER TABLE users
    ADD COLUMN media_bytes_used BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN media_items_used INT NOT NULL DEFAULT 0;

UPDATE users u
LEFT JOIN (
    SELECT user_id, COALESCE(SUM(file_size), 0) AS bytes_used, COUNT(*) AS items_used
    FROM media_resources
    GROUP BY user_id
) usage_totals ON usage_totals.user_id = u.id
SET u.media_bytes_used = COALESCE(usage_totals.bytes_used, 0),
    u.media_items_used = COALESCE(usage_totals.items_used, 0);

CREATE TABLE request_rate_limits (
    scope VARCHAR(40) NOT NULL,
    bucket_key CHAR(64) NOT NULL,
    available_tokens DECIMAL(12, 6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (scope, bucket_key),
    KEY idx_request_rate_limits_updated_at (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
