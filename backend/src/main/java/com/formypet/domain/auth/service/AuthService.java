package com.formypet.domain.auth.service;

import com.formypet.domain.auth.dto.request.KakaoLoginRequest;
import com.formypet.domain.auth.dto.request.LoginRequest;
import com.formypet.domain.auth.dto.request.RegisterRequest;
import com.formypet.domain.auth.dto.response.TokenResponse;

public interface AuthService {
    TokenResponse register(RegisterRequest request);
    TokenResponse login(LoginRequest request);
    TokenResponse kakaoLogin(KakaoLoginRequest request);
    void admitRegistration(String clientAddress);
    void admitLogin(String email,String clientAddress);
    void admitKakaoLogin(String clientAddress);
    TokenResponse refresh(String token);
    void logout(String token);
}
