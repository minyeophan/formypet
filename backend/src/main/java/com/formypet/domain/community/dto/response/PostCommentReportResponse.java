package com.formypet.domain.community.dto.response;

import com.formypet.domain.community.dto.PostCommentReportReason;

import java.time.Instant;

public record PostCommentReportResponse(
        Long id,
        Long commentId,
        PostCommentReportReason reason,
        String detail,
        Instant createdAt
) {
}
