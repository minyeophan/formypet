package com.petyilgi.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import io.swagger.v3.oas.annotations.media.Schema;

public record RegisterRequest(
        @Schema(description = "사용자 이메일", example = "user@example.com") @Email @NotBlank @Pattern(regexp = "^(?!.*@oauth\\..+\\.local$).*$", message = "사용할 수 없는 이메일 형식입니다.") String email,
        @Schema(description = "로그인 비밀번호(최소 8자)", format = "password", writeOnly = true) @NotBlank @Size(min = 8) String password,
        @Schema(description = "사용자 닉네임", example = "멍멍이") @NotBlank @Size(max = 50) String nickname
) {}
