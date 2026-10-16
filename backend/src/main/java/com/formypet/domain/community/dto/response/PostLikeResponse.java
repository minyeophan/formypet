package com.formypet.domain.community.dto.response;

public record PostLikeResponse(Long postId, boolean liked, int likesCount) {
    public static PostLikeResponse of(Long postId, boolean liked, int likesCount) {
        return new PostLikeResponse(postId, liked, likesCount);
    }
}
