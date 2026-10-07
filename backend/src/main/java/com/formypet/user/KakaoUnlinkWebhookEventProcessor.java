package com.formypet.user;

import com.formypet.auth.OAuthLifecycleGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class KakaoUnlinkWebhookEventProcessor {
    private final JdbcTemplate jdbc;
    private final OAuthLifecycleGuard lifecycle;
    private final AccountDeletionTransaction deletion;

    @Transactional
    public void process(long eventId, String providerUserId) {
        lifecycle.lock(providerUserId);
        if (jdbc.queryForList("""
                SELECT id FROM kakao_unlink_webhook_events
                WHERE id=? AND provider_user_id=? FOR UPDATE
                """, Long.class, eventId, providerUserId).isEmpty()) return;
        deletion.deleteAfterKakaoUnlink(providerUserId);
        jdbc.update("DELETE FROM kakao_unlink_webhook_events WHERE id=?", eventId);
    }
}
