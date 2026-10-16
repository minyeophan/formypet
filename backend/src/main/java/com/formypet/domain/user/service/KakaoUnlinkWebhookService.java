package com.formypet.domain.user.service;

public interface KakaoUnlinkWebhookService {
    boolean receive(String authorization, String appId, String providerUserId, String referrerType);
}
