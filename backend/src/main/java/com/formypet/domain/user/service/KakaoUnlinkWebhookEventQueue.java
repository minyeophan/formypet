package com.formypet.domain.user.service;

public interface KakaoUnlinkWebhookEventQueue {
    void enqueue(String providerUserId);
}
