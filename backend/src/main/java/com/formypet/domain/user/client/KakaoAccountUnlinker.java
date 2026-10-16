package com.formypet.domain.user.client;

public interface KakaoAccountUnlinker {
    boolean isConfigured();
    void unlink(String providerUserId);
}
