package com.petyilgi.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record TokenResponse(
        @Schema(description = "인증에 사용하는 access token", readOnly = true) String accessToken,
        @Schema(description = "갱신에 사용하는 refresh token", readOnly = true) String refreshToken) {
    public static TokenResponse of(String accessToken, String refreshToken) {
        return new TokenResponse(accessToken, refreshToken);
    }
}
