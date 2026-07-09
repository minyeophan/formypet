package com.petyilgi.community.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record PostCommentReportRequest(
        @NotNull PostCommentReportReason reason,
        @Size(max = 500) String detail
) {
}
