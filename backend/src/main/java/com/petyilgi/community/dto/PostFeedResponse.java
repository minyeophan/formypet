package com.petyilgi.community.dto;

import java.util.List;

public record PostFeedResponse(List<PostResponse> items, String nextCursor) {
    public static PostFeedResponse of(List<PostResponse> items, String nextCursor) {
        return new PostFeedResponse(items, nextCursor);
    }
}
