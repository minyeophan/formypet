package com.formypet.domain.auth.repository.jdbc;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class OAuthLifecycleLockRepository {
    private final JdbcTemplate jdbc;

    public void lockBucket(int bucket) {
        jdbc.queryForObject("SELECT bucket_id FROM oauth_lifecycle_locks WHERE bucket_id=? FOR UPDATE",
                Integer.class, bucket);
    }

    public boolean pendingCleanup(String providerId) {
        return !jdbc.queryForList("SELECT id FROM account_deletion_jobs WHERE provider_user_id=? FOR UPDATE",
                Long.class, providerId).isEmpty()
                || !jdbc.queryForList("SELECT id FROM kakao_unlink_webhook_events WHERE provider_user_id=? FOR UPDATE",
                Long.class, providerId).isEmpty();
    }
}
