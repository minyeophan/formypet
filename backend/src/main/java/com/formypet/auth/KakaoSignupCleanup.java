package com.formypet.auth;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name="app.account-deletion.scheduler-enabled",havingValue="true",matchIfMissing=true)
public class KakaoSignupCleanup {
    private final KakaoSignupIntents intents;
    @Scheduled(fixedDelayString="${app.policies.signup-cleanup-interval-ms:60000}")
    public void expire() { intents.expire(); }
}
