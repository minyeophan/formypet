package com.formypet.domain.user.repository.jdbc;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Cross-domain commands sharing the caller's account-deletion transaction. */
@Repository
@RequiredArgsConstructor
public class AccountDeletionCommands {
    private final JdbcTemplate jdbc;
    public boolean lockKakaoIdentity(long uid, String providerId) {
        return !jdbc.queryForList("SELECT id FROM oauth_accounts WHERE user_id=? AND provider='KAKAO' AND provider_user_id=? FOR UPDATE", Long.class, uid, providerId).isEmpty();
    }
    public List<Long> lockKakaoUsers(String providerId) {
        return jdbc.queryForList("SELECT user_id FROM oauth_accounts WHERE provider='KAKAO' AND provider_user_id=? FOR UPDATE", Long.class, providerId);
    }
    public List<Long> affectedPosts(long uid) {
        return jdbc.queryForList("""
                SELECT p.id FROM posts p WHERE p.user_id<>? AND (
                    EXISTS (SELECT 1 FROM post_comments c WHERE c.post_id=p.id AND c.user_id=?) OR
                    EXISTS (SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=?) OR
                    EXISTS (SELECT 1 FROM post_polls poll JOIN post_poll_votes v ON v.poll_id=poll.id
                            WHERE poll.post_id=p.id AND v.user_id=?)
                ) ORDER BY p.id
                """, Long.class, uid, uid, uid, uid);
    }
    public List<Long> affectedOptions(long uid) {
        return jdbc.queryForList("""
                SELECT DISTINCT v.option_id FROM post_poll_votes v
                JOIN post_polls poll ON poll.id=v.poll_id JOIN posts p ON p.id=poll.post_id
                WHERE v.user_id=? AND p.user_id<>?
                """, Long.class, uid, uid);
    }
    public int mediaCount(long uid) {
        Integer count = jdbc.queryForObject("SELECT COUNT(*) FROM media_resources WHERE user_id=?", Integer.class, uid);
        return count == null ? 0 : count;
    }
    public void queueMediaCleanup(long uid) {
        jdbc.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) SELECT storage_key FROM media_resources WHERE user_id=?", uid);
    }
    public void queueKakaoUnlink(String providerId) {
        jdbc.update("""
                INSERT INTO account_deletion_jobs(provider_user_id,next_attempt_at) VALUES (?,UTC_TIMESTAMP(6))
                ON DUPLICATE KEY UPDATE next_attempt_at=LEAST(next_attempt_at,VALUES(next_attempt_at))
                """, providerId);
    }
    public void deleteSupportData(long uid) {
        jdbc.update("""
                DELETE outbox FROM support_mail_outbox outbox
                JOIN support_tickets ticket ON ticket.id=outbox.ticket_id WHERE ticket.requester_user_id=?
                """, uid);
        jdbc.update("DELETE FROM support_tickets WHERE requester_user_id=?", uid);
    }
    public void deleteResetLimit(String key) {
        jdbc.update("DELETE FROM password_reset_limits WHERE bucket_key=?", key);
    }
    public void detachOtherAuthorsReplies(long uid) {
        jdbc.update("""
                UPDATE post_comments reply JOIN post_comments parent ON parent.id=reply.parent_comment_id
                JOIN posts post ON post.id=reply.post_id SET reply.parent_comment_id=NULL
                WHERE parent.user_id=? AND reply.user_id<>? AND post.user_id<>?
                """, uid, uid, uid);
    }
    public void markPending(long uid) {
        jdbc.update("UPDATE users SET account_status='DELETION_PENDING',auth_version=auth_version+1 WHERE id=?", uid);
    }
    public int deletePendingUser(long uid) {
        return jdbc.update("DELETE FROM users WHERE id=? AND account_status='DELETION_PENDING'", uid);
    }
    public void refreshPostCounts(long postId) {
        jdbc.update("""
                UPDATE posts p SET likes_count=(SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.id),
                  comments_count=(SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.id AND c.deleted_at IS NULL)
                WHERE p.id=?
                """, postId);
    }
    public void refreshOptionCounts(long optionId) {
        jdbc.update("UPDATE post_poll_options o SET votes_count=(SELECT COUNT(*) FROM post_poll_votes v WHERE v.option_id=o.id) WHERE o.id=?", optionId);
    }
}
