package com.formypet.user.dto;

import com.formypet.auth.domain.User;

public record UserProfileResponse(
        Long id,
        String email,
        String nickname,
        String profileImageUrl,
        String registrationSource
) {
    public static UserProfileResponse of(User user) {
        Long mediaId = user.getProfileMediaId();
        return new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                mediaId == null ? null : "/api/v1/media/" + mediaId,
                user.getRegistrationSource()
        );
    }
}
