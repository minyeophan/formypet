package com.petyilgi.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterRequest(
        @Email @NotBlank @Pattern(regexp = "^(?!.*@oauth\\..+\\.local$).*$", message = "사용할 수 없는 이메일 형식입니다.") String email,
        @NotBlank @Size(min = 8) String password,
        @NotBlank @Size(max = 50) String nickname
) {}
