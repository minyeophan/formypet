package com.petyilgi.community.dto;

public record PostLikeResponse(Long postId, boolean liked, int likesCount) {
    public static PostLikeResponse of(Long postId, boolean liked, int likesCount) {
        return new PostLikeResponse(postId, liked, likesCount);
    }
}
