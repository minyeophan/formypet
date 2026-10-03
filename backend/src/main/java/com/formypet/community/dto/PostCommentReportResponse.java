package com.formypet.community.dto;

import java.time.Instant;

public record PostCommentReportResponse(
        Long id,
        Long commentId,
        PostCommentReportReason reason,
        String detail,
        Instant createdAt
) {
}
