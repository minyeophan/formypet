package com.petyilgi.community.dto;

import java.util.List;

public record PostCommentFeedResponse(List<PostCommentResponse> items, String nextCursor) {
    public static PostCommentFeedResponse of(List<PostCommentResponse> items, String nextCursor) {
        return new PostCommentFeedResponse(items, nextCursor);
    }
}
