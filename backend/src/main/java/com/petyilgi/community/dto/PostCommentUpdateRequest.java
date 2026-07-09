package com.petyilgi.community.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PostCommentUpdateRequest(
        @NotBlank @Size(max = 1000) String content
) {
}
