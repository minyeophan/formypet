package com.petyilgi.notification;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
@Component @RequiredArgsConstructor
public class NotificationCleanupJob {
    private final NotificationService service;
    @Scheduled(cron = "0 15 3 * * *")
    public void cleanup() { service.cleanup(); }
}
