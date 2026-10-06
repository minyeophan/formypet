package com.formypet.common.ratelimit;

import jakarta.annotation.PostConstruct;
import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Data
@Component
@ConfigurationProperties(prefix = "app.request-limits")
public class RequestRateLimitProperties {
    private int loginAccountCapacity = 10;
    private int loginAccountRefillSeconds = 30;
    private int loginClientCapacity = 60;
    private int loginClientRefillSeconds = 1;
    private int loginGlobalCapacity = 60;
    private int loginGlobalRefillTokens = 5;
    private int loginGlobalRefillPeriodSeconds = 1;
    private int deletionEmailCapacity = 3;
    private int deletionEmailWindowSeconds = 3600;
    private int deletionEmailCooldownSeconds = 30;
    private int deletionClientCapacity = 10;
    private int deletionClientWindowSeconds = 3600;
    private int deletionGlobalCapacity = 100;
    private int deletionGlobalWindowSeconds = 3600;
    private long mediaUserBytes = 524288000L;
    private int mediaUserItems = 1000;
    private int mediaUploadCapacity = 20;
    private int mediaUploadRefillSeconds = 3;

    @PostConstruct
    void validate() {
        if (loginAccountCapacity < 1 || loginAccountRefillSeconds < 1 || loginClientCapacity < 1
                || loginClientRefillSeconds < 1 || loginGlobalCapacity < 1
                || loginGlobalRefillTokens < 1 || loginGlobalRefillPeriodSeconds < 1
                || deletionEmailCapacity < 1 || deletionEmailWindowSeconds < 1
                || deletionEmailCooldownSeconds < 1 || deletionClientCapacity < 1 || deletionClientWindowSeconds < 1
                || deletionGlobalCapacity < 1 || deletionGlobalWindowSeconds < 1
                || mediaUserBytes < 1 || mediaUserItems < 1 || mediaUploadCapacity < 1 || mediaUploadRefillSeconds < 1) {
            throw new IllegalStateException("Request limit settings must be positive");
        }
    }
}
