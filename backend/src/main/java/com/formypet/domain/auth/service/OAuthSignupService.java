package com.formypet.domain.auth.service;

import com.formypet.domain.auth.client.KakaoUserInfo;

public interface OAuthSignupService {
    com.formypet.domain.user.entity.User signupKakaoUser(KakaoUserInfo user);
}
