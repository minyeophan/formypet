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
        String repliesNextCursor,
        boolean blocked
) {
    public PostCommentResponse(Long id, Long userId, String authorNickname, String authorProfileImageUrl,
                               String content, LocalDateTime createdAt, LocalDateTime updatedAt,
                               boolean deleted, int commentsCount, Long parentCommentId, int replyCount,
                               List<PostCommentResponse> replies, String repliesNextCursor) {
        this(id, userId, authorNickname, authorProfileImageUrl, content, createdAt, updatedAt,
                deleted, commentsCount, parentCommentId, replyCount, replies, repliesNextCursor, false);
    }
}
