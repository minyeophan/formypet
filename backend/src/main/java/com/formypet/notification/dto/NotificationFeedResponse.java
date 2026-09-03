package com.formypet.notification.dto;
import java.util.List;
public record NotificationFeedResponse(List<NotificationResponse> items, String nextCursor, boolean hasMore, int unreadCount) {}
