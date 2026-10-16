package com.formypet.domain.auth.dto.request;

import jakarta.validation.constraints.NotBlank;
import org.springframework.lang.NonNull;

public record KakaoLoginRequest(@NotBlank @NonNull String accessToken,
                               String signupToken, com.formypet.domain.policy.dto.request.PolicyAcceptance policyAcceptance) {
    public KakaoLoginRequest(String accessToken) { this(accessToken,null,null); }
}
