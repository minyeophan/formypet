package com.formypet.domain.user.service.impl;

import com.formypet.domain.user.service.KakaoUnlinkWebhookEventQueue;

import com.formypet.domain.auth.security.OAuthLifecycleGuard;
import com.formypet.domain.user.repository.jdbc.KakaoWebhookRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class KakaoUnlinkWebhookEventQueueImpl implements KakaoUnlinkWebhookEventQueue {
    private final KakaoWebhookRepository events;
    private final OAuthLifecycleGuard lifecycle;

    @Transactional
    public void enqueue(String providerUserId) {
        lifecycle.lock(providerUserId);
        events.enqueue(providerUserId);
    }
}
