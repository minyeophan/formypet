package com.formypet.user;

import jakarta.validation.constraints.Size;

public record AccountDeletionRequest(
        @Size(max = 128) String password,
        @Size(max = 4096) String kakaoAccessToken) {
}
