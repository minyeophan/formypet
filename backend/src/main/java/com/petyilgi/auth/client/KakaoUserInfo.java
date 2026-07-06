package com.petyilgi.auth.client;

import org.springframework.lang.Nullable;

public record KakaoUserInfo(
        String id,
        @Nullable String email,
        boolean emailVerified,
        @Nullable String nickname
) {
}
