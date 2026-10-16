package com.formypet.domain.notification.service.impl;

import com.formypet.global.time.UtcTime;
import com.formypet.domain.notification.dto.request.NotificationSettingsRequest;
import com.formypet.domain.notification.dto.response.NotificationFeedResponse;
import com.formypet.domain.notification.dto.response.NotificationSettingsResponse;
import com.formypet.domain.notification.entity.Notification;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.repository.NotificationRepository;
import com.formypet.domain.notification.repository.jdbc.NotificationCommands;
import com.formypet.domain.notification.service.NotificationQueryService;
import com.formypet.domain.notification.service.NotificationReminderService;
import com.formypet.domain.notification.service.NotificationService;
import com.formypet.domain.notification.service.NotificationSettingsService;
import java.time.Instant;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class NotificationServiceImpl implements NotificationService {
    private final NotificationRepository notifications;
    private final NotificationCommands commands;
    private final NotificationQueryService queries;
    private final NotificationSettingsService settings;
    private final NotificationReminderService reminders;

    @Transactional
    public void create(Long recipient, Long actor, String nickname, NotificationType type, Long post, Long comment) {
        if (recipient == null || recipient.equals(actor)) return;
        if (commands.blockedActivity(recipient, actor, post)) return;
        notifications.saveAndFlush(Notification.activity(recipient, actor, nickname, type, post, comment,
                type.name(), nickname + "님의 활동이 있습니다.", UtcTime.toDatabase(Instant.now())));
    }

    @Override public void createReminder(Long recipient, NotificationType type, String sourceType, Long sourceId, LocalDateTime scheduledFor, String title, String body) { reminders.createReminder(recipient,type,sourceType,sourceId,scheduledFor,title,body); }

    @Override public int deletePendingReminders(String sourceType, Long sourceId) { return reminders.deletePendingReminders(sourceType,sourceId); }

    @Override public NotificationSettingsResponse getSettings(Long actorId) { return settings.getSettings(actorId); }

    @Override public NotificationSettingsResponse updateSettings(Long actorId, NotificationSettingsRequest request) { return settings.updateSettings(actorId,request); }

    @Override public NotificationFeedResponse list(Long actorId, String cursor, int limit) { return queries.list(actorId,cursor,limit); }

    @Override public void read(Long actorId, Long id) { queries.read(actorId,id); }

    @Override public void readAll(Long actorId) { queries.readAll(actorId); }

    @Override public int cleanup() { return queries.cleanup(); }
}
