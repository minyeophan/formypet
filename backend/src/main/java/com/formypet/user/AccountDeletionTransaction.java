package com.formypet.user;

import com.formypet.auth.SessionGuard;
import com.formypet.auth.recovery.RecoveryCrypto;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.formypet.common.exception.ApiException;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AccountDeletionTransaction {
    private final JdbcTemplate jdbc;
    private final SessionGuard sessions;
    private final PasswordEncoder passwords;
    private final RecoveryCrypto recoveryCrypto;

    @Transactional
    public AccountDeletionReceipt delete(String email, String password, String kakaoUserId) {
        SessionGuard.Snapshot user = sessions.lock(email);
        if ("LOCAL".equals(user.source())) {
            if (password == null || !passwords.matches(password, user.passwordHash())) throw SessionGuard.invalid();
            if (kakaoUserId != null) throw SessionGuard.invalid();
        } else if ("KAKAO".equals(user.source())) {
            if (kakaoUserId == null || jdbc.queryForList("""
                    SELECT id FROM oauth_accounts
                    WHERE user_id=? AND provider='KAKAO' AND provider_user_id=? FOR UPDATE
                    """, Long.class, user.id(), kakaoUserId).isEmpty()) throw SessionGuard.invalid();
        } else {
            throw SessionGuard.invalid();
        }

        List<Long> affectedPosts = jdbc.queryForList("""
                SELECT p.id FROM posts p
                WHERE p.user_id<>? AND (
                    EXISTS (SELECT 1 FROM post_comments c WHERE c.post_id=p.id AND c.user_id=?) OR
                    EXISTS (SELECT 1 FROM post_likes l WHERE l.post_id=p.id AND l.user_id=?) OR
                    EXISTS (SELECT 1 FROM post_polls poll JOIN post_poll_votes v ON v.poll_id=poll.id
                            WHERE poll.post_id=p.id AND v.user_id=?)
                ) ORDER BY p.id
                """, Long.class, user.id(), user.id(), user.id(), user.id());
        List<Long> affectedOptions = jdbc.queryForList("""
                SELECT DISTINCT v.option_id FROM post_poll_votes v
                JOIN post_polls poll ON poll.id=v.poll_id
                JOIN posts p ON p.id=poll.post_id
                WHERE v.user_id=? AND p.user_id<>?
                """, Long.class, user.id(), user.id());
        Integer mediaCount = jdbc.queryForObject(
                "SELECT COUNT(*) FROM media_resources WHERE user_id=?", Integer.class, user.id());

        jdbc.update("""
                INSERT IGNORE INTO media_cleanup_queue(storage_key)
                SELECT storage_key FROM media_resources WHERE user_id=?
                """, user.id());
        if (kakaoUserId != null) {
            jdbc.update("""
                    INSERT INTO account_deletion_jobs(provider_user_id,next_attempt_at)
                    VALUES (?,UTC_TIMESTAMP(6))
                    ON DUPLICATE KEY UPDATE next_attempt_at=LEAST(next_attempt_at,VALUES(next_attempt_at))
                    """, kakaoUserId);
        }

        jdbc.update("""
                DELETE outbox FROM support_mail_outbox outbox
                JOIN support_tickets ticket ON ticket.id=outbox.ticket_id
                WHERE ticket.requester_user_id=?
                """, user.id());
        jdbc.update("DELETE FROM support_tickets WHERE requester_user_id=?", user.id());

        if (recoveryCrypto.hasHmacSecret()) {
            String resetSubject = recoveryCrypto.digest("subject", "user:" + user.id());
            String resetLimit = recoveryCrypto.digest("limit", "request-subject\0" + resetSubject);
            jdbc.update("DELETE FROM password_reset_limits WHERE bucket_key=?", resetLimit);
        }

        jdbc.update("UPDATE users SET account_status='DELETION_PENDING',auth_version=auth_version+1 WHERE id=?", user.id());
        if (jdbc.update("DELETE FROM users WHERE id=? AND account_status='DELETION_PENDING'", user.id()) != 1) {
            throw new ApiException(HttpStatus.CONFLICT, "account-deletion", "Account deletion",
                    "계정 삭제를 완료하지 못했어요. 다시 시도해 주세요.", "ACCOUNT_DELETION_CONFLICT");
        }

        for (Long postId : affectedPosts) {
            jdbc.update("""
                    UPDATE posts p SET
                      likes_count=(SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.id),
                      comments_count=(SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.id AND c.deleted_at IS NULL)
                    WHERE p.id=?
                    """, postId);
        }
        for (Long optionId : affectedOptions) {
            jdbc.update("""
                    UPDATE post_poll_options o SET votes_count=(
                      SELECT COUNT(*) FROM post_poll_votes v WHERE v.option_id=o.id
                    ) WHERE o.id=?
                    """, optionId);
        }
        return AccountDeletionReceipt.accepted(kakaoUserId != null || mediaCount != null && mediaCount > 0);
    }
}
