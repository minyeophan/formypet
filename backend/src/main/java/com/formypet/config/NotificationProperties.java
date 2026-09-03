package com.formypet.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import java.time.ZoneId;

@ConfigurationProperties(prefix = "app.notification")
public record NotificationProperties(boolean schedulerEnabled, ZoneId timezone, long intervalMs, long lookbackMinutes) {}
