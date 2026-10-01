package com.formypet.notification;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class NotificationCleanupJobConfigurationTest {
    private final ApplicationContextRunner context = new ApplicationContextRunner()
            .withBean(NotificationService.class, () -> mock(NotificationService.class))
            .withUserConfiguration(NotificationCleanupJob.class);

    @Test
    void disabledNotificationSchedulerAlsoDisablesCleanup() {
        context.withPropertyValues("app.notification.scheduler-enabled=false")
                .run(app -> assertThat(app).doesNotHaveBean(NotificationCleanupJob.class));
    }

    @Test
    void cleanupRemainsEnabledByDefault() {
        context.run(app -> assertThat(app).hasSingleBean(NotificationCleanupJob.class));
    }
}
