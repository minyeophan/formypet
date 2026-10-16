package com.formypet.domain.community.dto.response;

import java.util.List;

public record PostCommentFeedResponse(List<PostCommentResponse> items, String nextCursor) {
    public static PostCommentFeedResponse of(List<PostCommentResponse> items, String nextCursor) {
        return new PostCommentFeedResponse(items, nextCursor);
    }
}
