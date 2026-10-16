package com.formypet.domain.auth.service.impl;

import com.formypet.domain.auth.service.KakaoSignupIntents;
import com.formypet.domain.auth.security.OAuthLifecycleGuard;
import com.formypet.domain.auth.dto.response.SignupCancellationResponse;

import com.formypet.domain.auth.security.RecoveryCrypto;
import com.formypet.global.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import com.formypet.domain.auth.repository.jdbc.KakaoSignupIntentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;
import org.springframework.transaction.support.TransactionTemplate;
import java.util.*;

@Service
@RequiredArgsConstructor
public class KakaoSignupIntentsImpl implements KakaoSignupIntents {
    private final KakaoSignupIntentRepository intents;
    private final OAuthLifecycleGuard lifecycle;
    private final TransactionTemplate transactions;
    @Value("${app.policies.kakao-signup-ttl-seconds:900}") private int ttl;

    @Transactional(propagation=Propagation.MANDATORY)
    public String begin(String providerId) {
        if (ttl < 60 || ttl > 3600) throw new IllegalStateException("Invalid signup intent TTL");
        String token=UUID.randomUUID()+"."+UUID.randomUUID();
        intents.upsert(providerId, RecoveryCrypto.hash(token), ttl);
        return token;
    }
    @Transactional(propagation=Propagation.MANDATORY)
    public void validate(String providerId, String token) {
        if (token == null || token.length()>200 || !intents.lockValid(providerId, RecoveryCrypto.hash(token))) {
            throw new ApiException(HttpStatus.CONFLICT,"kakao-signup-expired","Signup expired",
                    "가입 확인 시간이 만료됐습니다. 카카오 로그인부터 다시 진행해 주세요.","KAKAO_SIGNUP_EXPIRED");
        }
    }
    @Transactional(propagation=Propagation.MANDATORY)
    public void complete(String providerId) { intents.delete(providerId); }

    public SignupCancellationResponse cancel(String token) {
        return cancelHash(RecoveryCrypto.hash(token), false);
    }
    private SignupCancellationResponse cancelHash(String hash, boolean expiredOnly) {
        return transactions.execute(status -> {
            var provider=intents.findProvider(hash);
            if(provider.isEmpty()) return new SignupCancellationResponse("NO_PENDING_SIGNUP",false);
            String id=provider.orElseThrow();
            lifecycle.lock(id);
            if(!intents.lockMatching(id,hash,expiredOnly))
                return new SignupCancellationResponse("NO_PENDING_SIGNUP",false);
            boolean existing=intents.hasOAuthAccount(id);
            if(!existing) intents.enqueueUnlinkIfAbsent(id);
            complete(id);
            return new SignupCancellationResponse(existing?"EXISTING_ACCOUNT_UNCHANGED":"CANCELLED",!existing);
        });
    }
    public void expire() {
        for(String hash:intents.expiredHashes()) {
            cancelHash(hash,true);
        }
    }
}
