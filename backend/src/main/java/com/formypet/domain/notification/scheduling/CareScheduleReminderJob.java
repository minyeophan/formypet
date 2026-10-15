package com.formypet.domain.notification.scheduling;

import com.formypet.domain.notification.service.CareScheduleReminderService;
import java.time.*;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(name="app.notification.scheduler-enabled", havingValue="true", matchIfMissing=true)
@RequiredArgsConstructor
public class CareScheduleReminderJob {
    private final CareScheduleReminderService service;
    private final com.formypet.domain.notification.config.NotificationProperties properties;

    @Scheduled(fixedDelayString = "${app.notification.interval-ms:60000}")
    public void run() {
        try { service.createDueNotifications(ZonedDateTime.now(properties.timezone()).toLocalDateTime()); }
        catch (Exception ex) { org.slf4j.LoggerFactory.getLogger(getClass()).error("Care schedule reminder batch failed", ex); }
    }
}
