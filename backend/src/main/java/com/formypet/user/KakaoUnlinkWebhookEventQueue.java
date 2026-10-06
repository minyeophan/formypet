package com.formypet.user;

import com.formypet.auth.OAuthLifecycleGuard;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class KakaoUnlinkWebhookEventQueue {
    private final JdbcTemplate jdbc;
    private final OAuthLifecycleGuard lifecycle;

    @Transactional
    public void enqueue(String providerUserId) {
        lifecycle.lock(providerUserId);
        jdbc.update("""
                INSERT IGNORE INTO kakao_unlink_webhook_events(provider_user_id,next_attempt_at)
                VALUES (?,UTC_TIMESTAMP(6))
                """, providerUserId);
    }
}
