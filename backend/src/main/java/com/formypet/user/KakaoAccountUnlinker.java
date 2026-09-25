package com.formypet.user;

public interface KakaoAccountUnlinker {
    boolean isConfigured();
    void unlink(String providerUserId);
}
