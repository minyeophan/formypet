package com.formypet.support;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
@ConditionalOnProperty(prefix = "app.support.mail", name = "scheduler-enabled", havingValue = "true")
public class SupportMailScheduler {
    private final SupportMailProperties settings;
    private final SupportMailWorker worker;

    @Scheduled(fixedDelayString = "${app.support.mail.interval-ms:30000}")
    public void sendPending() {
        if (!settings.isEnabled()) return;
        try {
            for (int i = 0; i < 20 && worker.processOne(); i++) { /* bounded batch */ }
        } catch (Exception failure) {
            log.warn("Support mail batch failed ({})", failure.getClass().getSimpleName());
        }
    }
}
