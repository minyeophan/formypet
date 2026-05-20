package com.petyilgi.auth.client;

public interface KakaoUserClient {
    KakaoUserInfo fetchUser(String accessToken);
}
