package com.formypet.domain.auth;

import com.formypet.domain.auth.repository.jdbc.KakaoSignupIntentRepository;
import com.formypet.domain.auth.repository.jdbc.OAuthLifecycleLockRepository;
import com.formypet.domain.auth.security.RecoveryCrypto;
import com.formypet.domain.user.entity.User;
import com.formypet.domain.user.repository.UserRepository;
import com.formypet.support.IntegrationTestSupport;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class KakaoSignupRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired KakaoSignupIntentRepository intents;
    @Autowired OAuthLifecycleLockRepository lifecycle;
    @Autowired JdbcTemplate jdbc;
    @Autowired UserRepository users;

    @Test void rotationInvalidatesOldHashAndExpiredOnlyLockUsesDatabaseTime() {
        String provider = UUID.randomUUID().toString();
        String oldHash = RecoveryCrypto.hash(UUID.randomUUID().toString());
        String newHash = RecoveryCrypto.hash(UUID.randomUUID().toString());
        intents.upsert(provider, oldHash, 900);
        assertThat(intents.findProvider(oldHash)).contains(provider);
        assertThat(intents.lockValid(provider, oldHash)).isTrue();
        assertThat(intents.lockMatching(provider, oldHash, true)).isFalse();
        intents.upsert(provider, newHash, 900);
        assertThat(intents.findProvider(oldHash)).isEmpty();
        assertThat(intents.lockValid(provider, oldHash)).isFalse();
        assertThat(intents.lockMatching(provider, newHash, false)).isTrue();
        jdbc.update("UPDATE kakao_signup_intents SET expires_at=DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 SECOND) WHERE provider_user_id=?", provider);
        assertThat(intents.lockValid(provider, newHash)).isFalse();
        assertThat(intents.lockMatching(provider, newHash, true)).isTrue();
        assertThat(intents.expiredHashes()).contains(newHash);
        intents.delete(provider);
        assertThat(intents.findProvider(newHash)).isEmpty();
    }

    @Test void cleanupCurrentReadSeesEitherQueueAndRepeatedEnqueuePreservesRetryState() {
        String provider = UUID.randomUUID().toString();
        lifecycle.lockBucket(Math.floorMod(provider.hashCode(), 64));
        assertThat(lifecycle.pendingCleanup(provider)).isFalse();
        intents.enqueueUnlinkIfAbsent(provider);
        jdbc.update("UPDATE account_deletion_jobs SET attempts=5,last_error='marker',next_attempt_at='2030-01-01 00:00:00' WHERE provider_user_id=?", provider);
        intents.enqueueUnlinkIfAbsent(provider);
        assertThat(jdbc.queryForObject("SELECT attempts FROM account_deletion_jobs WHERE provider_user_id=?", Integer.class, provider)).isEqualTo(5);
        assertThat(jdbc.queryForObject("SELECT last_error FROM account_deletion_jobs WHERE provider_user_id=?", String.class, provider)).isEqualTo("marker");
        assertThat(lifecycle.pendingCleanup(provider)).isTrue();
        jdbc.update("DELETE FROM account_deletion_jobs WHERE provider_user_id=?", provider);
        assertThat(lifecycle.pendingCleanup(provider)).isFalse();
        jdbc.update("INSERT INTO kakao_unlink_webhook_events(provider_user_id,next_attempt_at) VALUES (?,UTC_TIMESTAMP(6))", provider);
        assertThat(lifecycle.pendingCleanup(provider)).isTrue();
    }

    @Test void existingOAuthIdentityCheckDoesNotMatchAnotherProvider() {
        String provider = UUID.randomUUID().toString();
        var user = users.saveAndFlush(User.create(UUID.randomUUID() + "@example.test", "hash", "oauth"));
        assertThat(intents.hasOAuthAccount(provider)).isFalse();
        jdbc.update("INSERT INTO oauth_accounts(user_id,provider,provider_user_id,created_at) VALUES (?,'OTHER',?,UTC_TIMESTAMP(6))", user.getId(), provider);
        assertThat(intents.hasOAuthAccount(provider)).isFalse();
        jdbc.update("INSERT INTO oauth_accounts(user_id,provider,provider_user_id,created_at) VALUES (?,'KAKAO',?,UTC_TIMESTAMP(6))", user.getId(), provider);
        assertThat(intents.hasOAuthAccount(provider)).isTrue();
    }
}
