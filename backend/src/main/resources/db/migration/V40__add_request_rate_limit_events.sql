CREATE TABLE request_rate_limit_events (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    scope VARCHAR(40) NOT NULL,
    bucket_key CHAR(64) NOT NULL,
    occurred_at DATETIME(6) NOT NULL,
    KEY idx_request_rate_limit_events_window (scope, bucket_key, occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
