package com.formypet.community.dto;

import java.time.LocalDateTime;

public record PostCommentReportResponse(
        Long id,
        Long commentId,
        PostCommentReportReason reason,
        String detail,
        LocalDateTime createdAt
) {
}
