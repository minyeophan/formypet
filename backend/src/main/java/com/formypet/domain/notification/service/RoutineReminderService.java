package com.formypet.domain.notification.service;

import java.time.LocalDateTime;

public interface RoutineReminderService {
    void createDueNotifications(LocalDateTime now);
}
