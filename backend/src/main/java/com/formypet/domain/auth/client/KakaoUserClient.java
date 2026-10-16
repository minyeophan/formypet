package com.formypet.domain.auth.client;

public interface KakaoUserClient {
    KakaoUserInfo fetchUser(String accessToken);
}
