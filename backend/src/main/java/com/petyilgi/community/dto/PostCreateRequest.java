package com.petyilgi.community.dto;

import jakarta.validation.constraints.NotBlank;

public record PostCreateRequest(
        @NotBlank String content,
        String petSpecies
) {
}
