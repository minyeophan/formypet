ALTER TABLE support_tickets ADD COLUMN target_author_id BIGINT NULL;

UPDATE support_tickets ticket JOIN posts post ON post.id=ticket.target_post_id
SET ticket.target_author_id=post.user_id WHERE ticket.kind='POST_REPORT';

UPDATE support_tickets ticket JOIN users author
ON CAST(CASE WHEN JSON_VALID(ticket.target_snapshot)
        THEN JSON_UNQUOTE(JSON_EXTRACT(ticket.target_snapshot,'$.user_id')) ELSE NULL END AS CHAR)=CAST(author.id AS CHAR)
SET ticket.target_author_id=author.id
WHERE ticket.kind='POST_REPORT' AND ticket.target_author_id IS NULL;

-- Unresolved historical authors remain NULL for operator review; do not infer or delete them.
ALTER TABLE support_mail_outbox DROP FOREIGN KEY fk_support_mail_ticket,
    ADD CONSTRAINT fk_support_mail_ticket_cascade FOREIGN KEY(ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE;
ALTER TABLE support_tickets ADD CONSTRAINT fk_support_target_author
    FOREIGN KEY(target_author_id) REFERENCES users(id) ON DELETE CASCADE;
