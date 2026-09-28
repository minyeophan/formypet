package com.formypet.auth.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record TokenResponse(
        @Schema(description = "인증에 사용하는 access token", readOnly = true) String accessToken,
        @Schema(description = "갱신에 사용하는 refresh token", readOnly = true) String refreshToken,
        boolean signupRequired, String signupToken) {
    public TokenResponse(String accessToken, String refreshToken) { this(accessToken,refreshToken,false,null); }
    public static TokenResponse of(String accessToken, String refreshToken) {
        return new TokenResponse(accessToken, refreshToken);
    }
    public static TokenResponse signup(String token) { return new TokenResponse(null,null,true,token); }
}
