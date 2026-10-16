package com.formypet.domain.user.service;

public interface KakaoUnlinkWebhookEventProcessor {
    void process(long eventId, String providerUserId);
}
