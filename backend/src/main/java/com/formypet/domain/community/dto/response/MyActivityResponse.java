package com.formypet.domain.community.dto.response;

import java.time.Instant;
import java.util.List;

public record MyActivityResponse(List<Item> items, String nextCursor) {
    public record Item(PostResponse post,
                       Instant activityAt,
                       Comment comment) {}
    public record Comment(Long id, Long parentId, String content) {}
}
