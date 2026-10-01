package com.formypet.auth;

import com.formypet.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.*;

@Component
@RequiredArgsConstructor
public class OAuthLifecycleGuard {
    private final JdbcTemplate jdbc;

    /** Acquire before users/oauth_accounts/job locks. Never call provider HTTP in this transaction. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void lock(String providerId) {
        jdbc.queryForObject("SELECT bucket_id FROM oauth_lifecycle_locks WHERE bucket_id=? FOR UPDATE",
                Integer.class, Math.floorMod(providerId.hashCode(), 64));
    }
    @Transactional(propagation = Propagation.MANDATORY)
    public void requireNoCleanup(String providerId) {
        if (!jdbc.queryForList("SELECT id FROM account_deletion_jobs WHERE provider_user_id=? FOR UPDATE", Long.class, providerId).isEmpty()) {
            throw new ApiException(HttpStatus.CONFLICT, "kakao-cleanup", "Kakao cleanup pending",
                    "이전 카카오 연결을 정리하고 있어요. 정리가 끝난 뒤 다시 시도해 주세요.", "KAKAO_CLEANUP_PENDING");
        }
    }
}
