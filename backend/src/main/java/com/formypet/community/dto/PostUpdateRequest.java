package com.formypet.community.dto;

import jakarta.validation.constraints.NotBlank;

public record PostUpdateRequest(
        @NotBlank String title,
        @NotBlank String category,
        @NotBlank String content,
        String petSpecies
) {
}
