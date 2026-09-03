package com.formypet.notification;

import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import java.time.*;

@Component
@ConditionalOnProperty(name="app.notification.scheduler-enabled", havingValue="true", matchIfMissing=true)
@RequiredArgsConstructor
public class RoutineReminderJob {
    private final RoutineReminderService service;
    private final com.formypet.config.NotificationProperties properties;

    @Scheduled(fixedDelayString = "${app.notification.interval-ms:60000}")
    public void run() {
        try { service.createDueNotifications(ZonedDateTime.now(properties.timezone()).toLocalDateTime()); }
        catch (Exception ex) { org.slf4j.LoggerFactory.getLogger(getClass()).error("Routine reminder batch failed", ex); }
    }
}
