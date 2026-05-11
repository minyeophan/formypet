package com.petyilgi.community.dto;

import java.time.LocalDateTime;
import java.util.List;

public record PostResponse(
        Long id,
        Long userId,
        String authorNickname,
        String title,
        String category,
        String petSpecies,
        String content,
        int likesCount,
        int commentsCount,
        boolean liked,
        LocalDateTime createdAt,
        List<String> mediaUrls,
        PollResponse poll
) {
    public static PostResponse of(Long id, Long userId, String authorNickname, String title, String category,
                                  String petSpecies, String content, int likesCount, int commentsCount,
                                  boolean liked, LocalDateTime createdAt, List<String> mediaUrls, PollResponse poll) {
        return new PostResponse(id, userId, authorNickname, title, category, petSpecies, content, likesCount,
                commentsCount, liked, createdAt, mediaUrls, poll);
    }

    public record PollResponse(
            Long id,
            String question,
            List<PollOptionResponse> options
    ) {
    }

    public record PollOptionResponse(
            Long id,
            String label,
            int votesCount,
            boolean votedByMe
    ) {
    }
}
