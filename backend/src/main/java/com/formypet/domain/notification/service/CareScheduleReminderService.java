package com.formypet.domain.notification.service;

import java.time.LocalDateTime;

public interface CareScheduleReminderService {
    void createDueNotifications(LocalDateTime now);
}
