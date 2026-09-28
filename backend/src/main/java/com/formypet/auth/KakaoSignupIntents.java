package com.formypet.auth;

import com.formypet.auth.recovery.RecoveryCrypto;
import com.formypet.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;
import org.springframework.transaction.support.TransactionTemplate;
import java.util.*;

@Service
@RequiredArgsConstructor
public class KakaoSignupIntents {
    private final JdbcTemplate jdbc;
    private final OAuthLifecycleGuard lifecycle;
    private final TransactionTemplate transactions;
    @Value("${app.policies.kakao-signup-ttl-seconds:900}") private int ttl;

    @Transactional(propagation=Propagation.MANDATORY)
    public String begin(String providerId) {
        if (ttl < 60 || ttl > 3600) throw new IllegalStateException("Invalid signup intent TTL");
        String token=UUID.randomUUID()+"."+UUID.randomUUID();
        jdbc.update("""
                INSERT INTO kakao_signup_intents(provider_user_id,token_hash,expires_at)
                VALUES (?,?,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL ? SECOND))
                ON DUPLICATE KEY UPDATE token_hash=VALUES(token_hash),expires_at=VALUES(expires_at)
                """, providerId, RecoveryCrypto.hash(token), ttl);
        return token;
    }
    @Transactional(propagation=Propagation.MANDATORY)
    public void validate(String providerId, String token) {
        if (token == null || token.length()>200 || jdbc.queryForList("""
                SELECT provider_user_id FROM kakao_signup_intents
                WHERE provider_user_id=? AND token_hash=? AND expires_at>UTC_TIMESTAMP(6) FOR UPDATE
                """, String.class, providerId, RecoveryCrypto.hash(token)).isEmpty()) {
            throw new ApiException(HttpStatus.CONFLICT,"kakao-signup-expired","Signup expired",
                    "가입 확인 시간이 만료됐습니다. 카카오 로그인부터 다시 진행해 주세요.","KAKAO_SIGNUP_EXPIRED");
        }
    }
    @Transactional(propagation=Propagation.MANDATORY)
    public void complete(String providerId) { jdbc.update("DELETE FROM kakao_signup_intents WHERE provider_user_id=?",providerId); }

    public record Cancellation(String status, boolean externalCleanupPending) {}
    public Cancellation cancel(String token) {
        return cancelHash(RecoveryCrypto.hash(token), false);
    }
    private Cancellation cancelHash(String hash, boolean expiredOnly) {
        return transactions.execute(status -> {
            var ids=jdbc.queryForList("SELECT provider_user_id FROM kakao_signup_intents WHERE token_hash=?",String.class,hash);
            if(ids.isEmpty()) return new Cancellation("NO_PENDING_SIGNUP",false);
            String id=ids.getFirst();
            lifecycle.lock(id);
            String expiry=expiredOnly?" AND expires_at<=UTC_TIMESTAMP(6)":"";
            if(jdbc.queryForList("SELECT provider_user_id FROM kakao_signup_intents WHERE provider_user_id=? AND token_hash=?"+expiry+" FOR UPDATE",String.class,id,hash).isEmpty())
                return new Cancellation("NO_PENDING_SIGNUP",false);
            boolean existing=!jdbc.queryForList("SELECT id FROM oauth_accounts WHERE provider='KAKAO' AND provider_user_id=? FOR UPDATE",Long.class,id).isEmpty();
            if(!existing) jdbc.update("""
                    INSERT IGNORE INTO account_deletion_jobs(provider_user_id,next_attempt_at) VALUES (?,UTC_TIMESTAMP(6))
                    """,id);
            complete(id);
            return new Cancellation(existing?"EXISTING_ACCOUNT_UNCHANGED":"CANCELLED",!existing);
        });
    }
    public void expire() {
        for(String hash:jdbc.queryForList("SELECT token_hash FROM kakao_signup_intents WHERE expires_at<=UTC_TIMESTAMP(6) ORDER BY expires_at LIMIT 50",String.class)) {
            cancelHash(hash,true);
        }
    }
}
