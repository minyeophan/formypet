package com.formypet.domain.notification.scheduling;

import com.formypet.domain.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component @RequiredArgsConstructor
@ConditionalOnProperty(name="app.notification.scheduler-enabled", havingValue="true", matchIfMissing=true)
public class NotificationCleanupJob {
    private final NotificationService service;
    @Scheduled(cron = "0 15 3 * * *")
    public void cleanup() { service.cleanup(); }
}
