package com.formypet.community.dto;

import java.time.LocalDateTime;
import java.util.List;

public record PostCommentResponse(
        Long id,
        Long userId,
        String authorNickname,
        String authorProfileImageUrl,
        String content,
        LocalDateTime createdAt,
        LocalDateTime updatedAt,
        boolean deleted,
        int commentsCount,
        Long parentCommentId,
        int replyCount,
        List<PostCommentResponse> replies,
        String repliesNextCursor
) {
}
