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
        assertThat(limits.getDeletionGlobalCapacity()).isEqualTo(100);
        assertThat(limits.getDeletionGlobalRefillTokens()).isEqualTo(100);
        assertThat(limits.getDeletionGlobalRefillPeriodSeconds()).isEqualTo(3600);
    }

    @Test
    void globalLoginBucketRefillsFiveTokensPerSecond() {
        assertThat(RequestRateLimiter.refilledTokens(0, 1, 60, 5, 1)).isEqualTo(5);
        assertThat(RequestRateLimiter.refilledTokens(0, 0.5, 60, 5, 1)).isEqualTo(2.5);
    }

    @Test
    void globalDeletionBucketRefillsOneHundredTokensPerHour() {
        assertThat(RequestRateLimiter.refilledTokens(0, 3600, 100, 100, 3600)).isEqualTo(100);
        assertThat(RequestRateLimiter.refilledTokens(0, 1800, 100, 100, 3600)).isEqualTo(50);
    }

    @Test
    void deletionEmailBucketCannotRefillBeforeItsHourlyWindow() {
        RequestRateLimitProperties limits = new RequestRateLimitProperties();

        assertThat(RequestRateLimiter.refilledTokens(0, 3599, limits.getDeletionEmailCapacity(), 1,
                limits.getDeletionEmailRefillSeconds())).isLessThan(1);
        assertThat(RequestRateLimiter.refilledTokens(0, 3600, limits.getDeletionEmailCapacity(), 1,
                limits.getDeletionEmailRefillSeconds())).isEqualTo(1);
    }
}
