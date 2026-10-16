package com.formypet.domain.notification.service.impl;

import com.formypet.domain.user.repository.UserRepository;
import com.formypet.global.exception.ApiException;
import com.formypet.global.time.UtcTime;
import com.formypet.domain.notification.dto.response.NotificationFeedResponse;
import com.formypet.domain.notification.dto.response.NotificationResponse;
import com.formypet.domain.notification.entity.Notification;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.repository.NotificationRepository;
import com.formypet.domain.notification.repository.jdbc.NotificationCommands;
import com.formypet.domain.notification.repository.query.NotificationRow;
import com.formypet.domain.notification.service.NotificationQueryService;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class NotificationQueryServiceImpl implements NotificationQueryService {
    private final NotificationRepository notifications;
    private final NotificationCommands commands;
    private final UserRepository users;

    @Transactional(readOnly = true)
    public NotificationFeedResponse list(Long actorId, String cursor, int limit) {
        Long userId = users.findById(actorId).orElseThrow().getId();
        int size = Math.max(1, Math.min(limit, 50));
        Long beforeId = cursor == null || cursor.isBlank() ? null : Long.valueOf(cursor);
        var rows = notifications.findVisible(userId, beforeId, size + 1);
        boolean more = rows.size() > size;
        if (more) rows = rows.subList(0, size);
        var items = rows.stream().map(NotificationQueryServiceImpl::response).toList();
        return new NotificationFeedResponse(items, more ? items.getLast().id().toString() : null,
                more, notifications.countUnreadVisible(userId));
    }

    @Transactional
    public void read(Long actorId, Long id) {
        Long userId = users.findById(actorId).orElseThrow().getId();
        if (commands.markRead(userId, id, UtcTime.toDatabase(Instant.now())) == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "notification-not-found", "Notification Not Found",
                    "Notification not found.", "NOTIFICATION_NOT_FOUND");
        }
    }

    @Transactional
    public void readAll(Long actorId) {
        Long userId = users.findById(actorId).orElseThrow().getId();
        commands.markAllRead(userId, UtcTime.toDatabase(Instant.now()));
    }

    @Transactional
    public int cleanup() { return notifications.deleteExpired(); }

    private static NotificationResponse response(NotificationRow row) {
        return new NotificationResponse(row.id(), row.actorUserId(), row.actorNickname(),
                NotificationType.valueOf(row.type()), row.postId(), row.commentId(), row.sourceType(), row.sourceId(),
                row.scheduledFor(), row.title(), row.body(), UtcTime.fromDatabase(row.readAt()), UtcTime.fromDatabase(row.createdAt()));
    }
}
