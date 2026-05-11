package com.petyilgi.user.dto;

import com.petyilgi.auth.domain.User;

public record UserProfileResponse(
        String email,
        String nickname,
        String profileImageUrl
) {
    public static UserProfileResponse of(User user) {
        Long mediaId = user.getProfileMediaId();
        return new UserProfileResponse(
                user.getEmail(),
                user.getNickname(),
                mediaId == null ? null : "/api/v1/media/" + mediaId
        );
    }
}
