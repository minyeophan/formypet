package com.formypet.domain.auth.repository.jdbc;

import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Atomic intent rotation and current reads inside the caller's lifecycle transaction. */
@Repository
@RequiredArgsConstructor
public class KakaoSignupIntentRepository {
    private final JdbcTemplate jdbc;

    public void upsert(String providerId, String tokenHash, int ttlSeconds) {
        jdbc.update("""
                INSERT INTO kakao_signup_intents(provider_user_id,token_hash,expires_at)
                VALUES (?,?,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL ? SECOND))
                ON DUPLICATE KEY UPDATE token_hash=VALUES(token_hash),expires_at=VALUES(expires_at)
                """, providerId, tokenHash, ttlSeconds);
    }

    public Optional<String> findProvider(String tokenHash) {
        return jdbc.queryForList("SELECT provider_user_id FROM kakao_signup_intents WHERE token_hash=?",
                String.class, tokenHash).stream().findFirst();
    }

    public boolean lockValid(String providerId, String tokenHash) {
        return !jdbc.queryForList("""
                SELECT provider_user_id FROM kakao_signup_intents
                WHERE provider_user_id=? AND token_hash=? AND expires_at>UTC_TIMESTAMP(6) FOR UPDATE
                """, String.class, providerId, tokenHash).isEmpty();
    }

    public boolean lockMatching(String providerId, String tokenHash, boolean expiredOnly) {
        String expiry = expiredOnly ? " AND expires_at<=UTC_TIMESTAMP(6)" : "";
        return !jdbc.queryForList("SELECT provider_user_id FROM kakao_signup_intents WHERE provider_user_id=? AND token_hash=?"
                + expiry + " FOR UPDATE", String.class, providerId, tokenHash).isEmpty();
    }

    public boolean hasOAuthAccount(String providerId) {
        return !jdbc.queryForList("SELECT id FROM oauth_accounts WHERE provider='KAKAO' AND provider_user_id=? FOR UPDATE",
                Long.class, providerId).isEmpty();
    }

    public void enqueueUnlinkIfAbsent(String providerId) {
        jdbc.update("INSERT IGNORE INTO account_deletion_jobs(provider_user_id,next_attempt_at) VALUES (?,UTC_TIMESTAMP(6))",
                providerId);
    }

    public void delete(String providerId) {
        jdbc.update("DELETE FROM kakao_signup_intents WHERE provider_user_id=?", providerId);
    }

    public List<String> expiredHashes() {
        return jdbc.queryForList("SELECT token_hash FROM kakao_signup_intents WHERE expires_at<=UTC_TIMESTAMP(6) ORDER BY expires_at LIMIT 50",
                String.class);
    }
}
