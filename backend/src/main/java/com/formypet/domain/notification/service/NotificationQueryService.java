package com.formypet.domain.notification.service;

import com.formypet.domain.notification.dto.response.NotificationFeedResponse;

public interface NotificationQueryService {
    NotificationFeedResponse list(Long actorId, String cursor, int limit);
    void read(Long actorId, Long id);
    void readAll(Long actorId);
    int cleanup();
}
