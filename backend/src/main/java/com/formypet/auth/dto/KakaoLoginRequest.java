package com.formypet.auth.dto;

import jakarta.validation.constraints.NotBlank;
import org.springframework.lang.NonNull;

public record KakaoLoginRequest(@NotBlank @NonNull String accessToken) {
}
