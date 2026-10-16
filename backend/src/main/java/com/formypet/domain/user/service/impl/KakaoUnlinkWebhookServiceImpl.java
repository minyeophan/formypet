package com.formypet.domain.user.service.impl;

import com.formypet.domain.user.security.KakaoUnlinkWebhookAuthorizer;
import com.formypet.domain.user.service.KakaoUnlinkWebhookService;
import com.formypet.domain.user.service.KakaoUnlinkWebhookEventQueue;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class KakaoUnlinkWebhookServiceImpl implements KakaoUnlinkWebhookService {
    private final KakaoUnlinkWebhookEventQueue eventQueue;
    private final KakaoUnlinkWebhookAuthorizer authorizer;

    public KakaoUnlinkWebhookServiceImpl(
            KakaoUnlinkWebhookEventQueue eventQueue,
            @Value("${app.kakao.app-id:}") String appId,
            @Value("${app.account-deletion.kakao-admin-key:}") String primaryAdminKey) {
        this.eventQueue = eventQueue;
        this.authorizer = new KakaoUnlinkWebhookAuthorizer(appId, primaryAdminKey);
    }

    public boolean receive(String authorization, String appId, String providerUserId, String referrerType) {
        if (!authorizer.authorizes(authorization, appId, providerUserId, referrerType)) return false;
        eventQueue.enqueue(providerUserId);
        return true;
    }
}
