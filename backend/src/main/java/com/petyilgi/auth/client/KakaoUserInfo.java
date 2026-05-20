package com.petyilgi.auth.client;

public record KakaoUserInfo(
        String id,
        String email,
        boolean emailVerified,
        String nickname
) {
}
