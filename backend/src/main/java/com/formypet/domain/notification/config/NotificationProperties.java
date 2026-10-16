package com.formypet.domain.notification.config;

import java.time.ZoneId;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.notification")
public record NotificationProperties(boolean schedulerEnabled, ZoneId timezone, long intervalMs, long lookbackMinutes) {}
