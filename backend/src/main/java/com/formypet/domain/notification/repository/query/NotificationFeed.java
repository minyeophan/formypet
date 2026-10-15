package com.formypet.domain.notification.repository.query;

import java.util.List;

public interface NotificationFeed {
    List<NotificationRow> findVisible(long recipient, Long cursor, int size);
}
