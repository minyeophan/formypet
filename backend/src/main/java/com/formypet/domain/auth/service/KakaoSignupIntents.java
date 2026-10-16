package com.formypet.domain.auth.service;

import com.formypet.domain.auth.dto.response.SignupCancellationResponse;

public interface KakaoSignupIntents {
    String begin(String providerId);
    void validate(String providerId,String token);
    void complete(String providerId);
    SignupCancellationResponse cancel(String token);
    void expire();
}
