package com.formypet.common.ratelimit;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class RequestRateLimiterTest {

    @Test
    void globalBucketDefaultsMatchThePublishedLimits() {
        RequestRateLimitProperties limits = new RequestRateLimitProperties();

        assertThat(limits.getLoginGlobalCapacity()).isEqualTo(60);
        assertThat(limits.getLoginGlobalRefillTokens()).isEqualTo(5);
        assertThat(limits.getLoginGlobalRefillPeriodSeconds()).isEqualTo(1);
        assertThat(limits.getDeletionEmailCapacity()).isEqualTo(3);
        assertThat(limits.getDeletionEmailWindowSeconds()).isEqualTo(3600);
        assertThat(limits.getDeletionClientCapacity()).isEqualTo(10);
        assertThat(limits.getDeletionClientWindowSeconds()).isEqualTo(3600);
        assertThat(limits.getDeletionGlobalCapacity()).isEqualTo(100);
        assertThat(limits.getDeletionGlobalWindowSeconds()).isEqualTo(3600);
    }

    @Test
    void globalLoginBucketRefillsFiveTokensPerSecond() {
        assertThat(RequestRateLimiter.refilledTokens(0, 1, 60, 5, 1)).isEqualTo(5);
        assertThat(RequestRateLimiter.refilledTokens(0, 0.5, 60, 5, 1)).isEqualTo(2.5);
    }

}
