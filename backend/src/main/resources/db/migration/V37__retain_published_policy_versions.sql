CREATE TABLE policy_publications (
    document_type VARCHAR(32) NOT NULL,
    document_version VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body MEDIUMTEXT NOT NULL,
    published_at DATETIME(6) NOT NULL,
    effective_at DATETIME(6) NOT NULL,
    acceptance_revision VARCHAR(64) NULL,
    content_hash CHAR(64) NOT NULL,
    PRIMARY KEY(document_type,document_version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE policy_runtime (
    id INT PRIMARY KEY,
    enforcement_enabled BOOLEAN NOT NULL DEFAULT FALSE
) ENGINE=InnoDB;
INSERT INTO policy_runtime(id,enforcement_enabled) VALUES (1,FALSE);
