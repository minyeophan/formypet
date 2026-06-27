package com.petyilgi.community.dto;

import java.time.LocalDateTime;

public record PostCommentResponse(
        Long id,
        Long userId,
        String authorNickname,
        String authorProfileImageUrl,
        String content,
        LocalDateTime createdAt,
        int commentsCount
) {
}
