package com.formypet.auth.client;

public interface KakaoUserClient {
    KakaoUserInfo fetchUser(String accessToken);
}
