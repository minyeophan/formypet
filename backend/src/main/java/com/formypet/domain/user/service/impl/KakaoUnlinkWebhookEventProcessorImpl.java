package com.formypet.domain.user.service.impl;

import com.formypet.domain.user.service.AccountDeletionTransaction;
import com.formypet.domain.user.service.KakaoUnlinkWebhookEventProcessor;

import com.formypet.domain.auth.security.OAuthLifecycleGuard;
import com.formypet.domain.user.repository.jdbc.KakaoWebhookRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class KakaoUnlinkWebhookEventProcessorImpl implements KakaoUnlinkWebhookEventProcessor {
    private final KakaoWebhookRepository events;
    private final OAuthLifecycleGuard lifecycle;
    private final AccountDeletionTransaction deletion;

    @Transactional
    public void process(long eventId, String providerUserId) {
        lifecycle.lock(providerUserId);
        if (!events.lockEvent(eventId, providerUserId)) return;
        deletion.deleteAfterKakaoUnlink(providerUserId);
        events.delete(eventId);
    }
}
