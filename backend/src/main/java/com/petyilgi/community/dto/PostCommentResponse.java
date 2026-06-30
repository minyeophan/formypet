package com.petyilgi.community.dto;

import java.time.LocalDateTime;
import java.util.List;

public record PostCommentResponse(
        Long id,
        Long userId,
        String authorNickname,
        String authorProfileImageUrl,
        String content,
        LocalDateTime createdAt,
        int commentsCount,
        Long parentCommentId,
        int replyCount,
        List<PostCommentResponse> replies,
        String repliesNextCursor
) {
}
