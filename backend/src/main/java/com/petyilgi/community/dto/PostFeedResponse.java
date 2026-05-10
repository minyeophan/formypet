package com.petyilgi.community.dto;

import java.util.List;

public record PostFeedResponse(List<PostResponse> items, Long nextCursor) {
    public static PostFeedResponse of(List<PostResponse> items, Long nextCursor) {
        return new PostFeedResponse(items, nextCursor);
    }
}
