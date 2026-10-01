package com.formypet.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UserProfileUpdateRequest(
        @NotBlank
        @Size(max = 50)
        String nickname
) {
}
