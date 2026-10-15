package com.formypet.domain.notification.dto.response;

import java.util.List;

public record NotificationFeedResponse(List<NotificationResponse> items, String nextCursor, boolean hasMore, int unreadCount) {}
