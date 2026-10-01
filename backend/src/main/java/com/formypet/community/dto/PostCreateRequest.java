package com.formypet.community.dto;

import jakarta.validation.constraints.NotBlank;

import java.util.List;

public record PostCreateRequest(
        @NotBlank String title,
        @NotBlank String category,
        @NotBlank String content,
        String petSpecies,
        PollCreateRequest poll
) {
    public record PollCreateRequest(
            @NotBlank String question,
            List<@NotBlank String> options
    ) {
    }
}
