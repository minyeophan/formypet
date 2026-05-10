package com.petyilgi.community.dto;

import java.time.LocalDateTime;

public record PostResponse(
        Long id,
        Long userId,
        String authorNickname,
        String petSpecies,
        String content,
        int likesCount,
        boolean liked,
        LocalDateTime createdAt
) {
    public static PostResponse of(Long id, Long userId, String authorNickname, String petSpecies,
                                  String content, int likesCount, boolean liked, LocalDateTime createdAt) {
        return new PostResponse(id, userId, authorNickname, petSpecies, content, likesCount, liked, createdAt);
    }
}
