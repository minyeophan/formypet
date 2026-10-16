package com.formypet.domain.auth.security;

import com.formypet.global.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import com.formypet.domain.auth.repository.jdbc.OAuthLifecycleLockRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.*;

@Component
@RequiredArgsConstructor
public class OAuthLifecycleGuard {
    private final OAuthLifecycleLockRepository locks;

    /** Acquire before users/oauth_accounts/job locks. Never call provider HTTP in this transaction. */
    @Transactional(propagation = Propagation.MANDATORY)
    public void lock(String providerId) {
        locks.lockBucket(Math.floorMod(providerId.hashCode(), 64));
    }
    @Transactional(propagation = Propagation.MANDATORY)
    public void requireNoCleanup(String providerId) {
        if (locks.pendingCleanup(providerId)) {
            throw new ApiException(HttpStatus.CONFLICT, "kakao-cleanup", "Kakao cleanup pending",
                    "이전 카카오 연결을 정리하고 있어요. 정리가 끝난 뒤 다시 시도해 주세요.", "KAKAO_CLEANUP_PENDING");
        }
    }
}
