package com.formypet.domain.community.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PostCommentUpdateRequest(
        @NotBlank @Size(max = 1000) String content
) {
}
